####################################################
# Appendix 1
####################################################

#Installing libraries

install.packages("tidyverse", dependencies = TRUE)
install.packages("lmtest", dependencies = TRUE)
install.packages("sandwich", dependencies = TRUE)
install.packages("MatchIt", dependencies = TRUE)

#load libraries

library("tidyverse")
library("lmtest")
library("sandwich")
library("MatchIt")

#Load dataset from GitHub

smk_data <- read_csv("https://raw.githubusercontent.com/gckc123/Causal_Analysis_Addiction_Examples/main/smoking_psyc_distress.csv")

#recode variable into "factor" variable

smk_data$remoteness <- as.factor(smk_data$remoteness)

#matching

smk_matching <- matchit(smoker ~ sex + indigeneity + high_school + partnered + remoteness + language + risky_alcohol + age, data = smk_data, method = "optimal", distance = "glm")
summary(smk_matching)

plot(summary(smk_matching), abs = FALSE)

#extract the matched data

matched_data <- match.data(smk_matching)

#estimate the treatment effect

smk_model1 <- lm(psyc_distress ~ smoker, data = matched_data, weights = weights)
summary(smk_model1)
coeftest(smk_model1, vcov. = vcovCL, cluster = ~subclass)
coefci(smk_model1, vcov. = vcovCL, cluster = ~subclass, level = 0.95)


#doubly robust estimation

smk_model2 <- lm(psyc_distress ~ smoker + sex + indigeneity + high_school + partnered + remoteness + language + risky_alcohol + age, data = matched_data, weights = weights)
summary(smk_model2)
coeftest(smk_model2, vcov. = vcovCL, cluster = ~subclass)
coefci(smk_model2, vcov. = vcovCL, cluster = ~subclass, level = 0.95)

####################################################
# Appendix 2
####################################################

#load the libraries

library("twang")
library("survey")
library("tidyverse")

#load the data from GitHub

smk_data <- read_csv("https://raw.githubusercontent.com/gckc123/Causal_Analysis_Addiction_Examples/main/smoking_psyc_distress.csv")

#recode variable into factor variable

smk_data$remoteness <- as.factor(smk_data$remoteness)

#IPTW

smk_iptw <- ps(smoker ~ sex + indigeneity + high_school + partnered + remoteness + language + risky_alcohol + age, interaction.depth = 3, data = as.data.frame(smk_data), n.tree = 10000, estimand = "ATE", verbose = FALSE)

plot(smk_iptw)
bal.table(smk_iptw)

#extract the weights

smk_data$weight <- get.weights(smk_iptw, stop.method = "es.mean")

#estimate the treatment effect

design_iptw <- svydesign(ids = ~1, weights = ~weight, data = smk_data)
smk_model3 <- svyglm(psyc_distress ~ smoker, design = design_iptw)
summary(smk_model3)
confint(smk_model3)

#doubly robust estimation

smk_model4 <- svyglm(psyc_distress ~ smoker + sex + indigeneity + high_school + partnered + remoteness + language + risky_alcohol + age, design = design_iptw)
summary(smk_model4)
confint(smk_model4)

####################################################
# Appendix 3
####################################################

#load the libraries

library("tidyverse")
library("twang")
library("survey")


#load the data from GitHub

alc_data <- read_csv("https://raw.githubusercontent.com/gckc123/Causal_Analysis_Addiction_Examples/main/home_alc.csv")

#IPTW

alc_iptw <- iptw(list(home_alc_2 ~ home_alc_1 + alc_use1 + alc_peer1 + smk1,
                      home_alc_3 ~ alc_use2 + alc_peer2 + smk2,
                      home_alc_4 ~ alc_use3 + alc_peer3 + smk3
),
timeInvariant ~ sex,
data = as.data.frame(alc_data),
cumulative = TRUE,
priorTreatment = TRUE,
stop.method = "es.max",
n.trees = 10000)

plot(alc_iptw, plots = 1)

bal.table(alc_iptw)

#extract the unstabilised weights
alc_data$unstab_weight <- get.weights.unstab(alc_iptw, stop.method = "es.mean")[,1]

#calculate the numerators of stabilised weights

num_fm <- list(glm(home_alc_2 ~ 1, family = binomial, data = alc_data),
               glm(home_alc_3 ~ home_alc_2, family = binomial, data = alc_data),
               glm(home_alc_4 ~ home_alc_2 + home_alc_3, family = binomial, data = alc_data))

num_weights <- get.weights.num(alc_iptw, num_fm)

alc_data$stab_weight <- num_weights* alc_data$unstab_weight

#calculate the cumulative exposure
alc_data$total_home_alc = alc_data$home_alc_2 + alc_data$home_alc_3 + alc_data$home_alc_4 
alc_data$total_home_alc = as.factor(alc_data$total_home_alc)

#estimate the treatment effect

design_iptw <- svydesign(ids = ~1, weights = ~stab_weight, data = alc_data)
alc_model <- svyglm(adult_alc_risky ~ total_home_alc, design = design_iptw, family = binomial)
summary(alc_model)
exp(coef(alc_model))
exp(confint(alc_model))

####################################################
# Appendix 4
####################################################

#install the libraries

install.packages("nlme", dependencies = TRUE)
install.packages("ggplot2", dependencies = TRUE)

#load the libraries
library(tidyverse)
library(nlme)
library(ggplot2)

#load the dataset

alc_mup_data <- read_csv("https://statsnotebook.io/blog/data_management/example_data/alcohol_data_NTWA.csv")

#convert the variable into factor variables

alc_mup_data$state <- factor(alc_mup_data$state, exclude = c("", NA))
alc_mup_data$intervention <- factor(alc_mup_data$intervention, exclude = c("", NA))

#change the reference level to be ???Western Australia???
alc_mup_data$state <- relevel(alc_mup_data$state, ref="WA")

#generate descriptive statistics

alc_mup_data %>%
  group_by(state, intervention) %>%
  summarize(count = n(),
            M_alcohol = mean(alcohol, na.rm = TRUE),
            Mdn_alcohol = median(alcohol, na.rm = TRUE),
            SD_alcohol = sd(alcohol, na.rm = TRUE),
            IQR_alcohol = IQR(alcohol, na.rm = TRUE)
  ) %>% 
  print()

#visualise the data

ggplot(alc_mup_data) +
  geom_boxplot(aes(y=alcohol, x=state, fill = intervention))

#estimate the intervention effect

res <- gls(alcohol ~ time*intervention*state,
           data = alc_mup_data,
           correlation = corARMA(p = 1, form =~ time | state), method = "ML")
summary(res)

#generating the model-based prediction
alc_mup_data$predicted <- res$fitted

#generating the interaction for ggplots
groups = interaction(alc_mup_data$intervention,alc_mup_data$state)
#ploting the time series
plot <- ggplot() +
  geom_point(data = alc_mup_data, aes(y = alcohol, x = time, color = state)) +
  geom_line(data = alc_mup_data, aes(y = predicted, x = time, color = state, group = groups)) +
  geom_vline(xintercept = max((alc_mup_data %>% filter(intervention == "0"))$time), linetype = 
               "dashed") +
  theme_bw(base_family = "sans") +
  theme(legend.position = "bottom")
plot


#extract the residuals
alc_mup_data$residuals <- residuals(res)

#plot the partial ACF
acf(alc_mup_data[alc_mup_data$state == "NT",]$residuals, type = "partial")
acf(alc_mup_data[alc_mup_data$state == "WA",]$residuals, type = "partial")


#refit the model with lag-4 auto-correlation

res2 <- gls(alcohol ~ time*intervention*state,
            data = alc_mup_data,
            correlation = corARMA(p = 4, form =~ time | state), method = "ML")
summary(res2)

#adjust for seasonality

#install the tsModel library
install.packages("tsModel", dependencies = TRUE)

#load the tsModel library
library(tsModel)

#The harmonic function is used to calculate the harmonic terms calculate based on sine and cosine function
#the first parameter of this function specifies the time variable
#the second specifies the number of sine and cosine pairs to include
#the third specifies the length of the period

alc_mup_data <- cbind(alc_mup_data, data.frame(harmonic(alc_mup_data$time, 1, 12)))
alc_mup_data <- alc_mup_data %>% 
  rename(harmonic1 = X1,
         harmonic2 = X2)
res <- gls(alcohol ~ time*intervention*state + harmonic1 + harmonic2,
           data = alc_mup_data,
           correlation = corARMA(p = 1, form =~ time | state), method = "ML")
summary(res)

#calcluate the predicted value
alc_mup_data$predicted <- res$fitted
groups = interaction(alc_mup_data$intervention,alc_mup_data$state)

#calculate the predicted linear trend for data visualisation
alc_mup_data.linear <- alc_mup_data
alc_mup_data.linear$harmonic1 <- 0
alc_mup_data.linear$harmonic2 <- 0
alc_mup_data.linear$predicted <- predict(res, alc_mup_data.linear)

#plot the time series
plot <- ggplot() +
  geom_point(data = alc_mup_data, aes(y = alcohol, x = time, color = state)) +
  geom_line(data = alc_mup_data, aes(y = predicted, x = time, color = state, group = groups), linetype = "dashed") +
  geom_line(data = alc_mup_data.linear, aes(y = predicted, x = time, color = state, group = groups)) +
  geom_vline(xintercept = max((alc_mup_data %>% filter(intervention == "0"))$time), linetype = "dashed") +
  theme_bw(base_family = "sans") +
  theme(legend.position = "bottom")
plot


