#' ---
#' title: "Bayesian data analysis demo 11.2"
#' author: "Aki Vehtari, Markus Paasiniemi"
#' date: "`r format(Sys.Date())`"
#' output:
#'   html_document:
#'     theme: readable
#'     code_download: true
#' ---

#' ## Metropolis algorithm
#' 

#' ggplot2 is used for plotting, tidyr for manipulating data frames
#+ setup, message=FALSE, error=FALSE, warning=FALSE
library(ggplot2)
theme_set(theme_minimal())
library(tidyr)
library(gganimate)
library(ggforce)
library(MASS)
library(posterior)
library(rprojroot)
root<-has_file(".BDA_R_demos_root")$make_fix_file()

#' Parameters of a normal distribution used as a toy target distribution
y1 <- 0
y2 <- 0
r <- 0.8
Sigma <- diag(2)
Sigma[1, 2] <- r
Sigma[2, 1] <- r
#' Metropolis proposal distribution scale
sp <- 0.3

#' Sample from the toy distribution to visualize 90% HPD
#' interval with ggplot's stat_ellipse()
dft <- data.frame(mvrnorm(100000, c(0, 0), Sigma))
#' see BDA3 p. 85 for how to compute HPD for multivariate normal
#' in 2d-case contour for 90% HPD is an ellipse, whose semimajor
#' axes can be computed from the eigenvalues of the covariance
#' matrix scaled by a value selected to get ellipse match the
#' density at the edge of 90% HPD. Angle of the ellipse could be
#' computed from the eigenvectors, but since the marginals are same
#' we know that angle is pi/4

#' Starting value of the chain
t1 <- -2.5
t2 <- 2.5
#' Number of iterations.
M <- 5000

#' Insert your own Metropolis sampling here
# Allocate memory for the sample
tt <- matrix(rep(0, 2*M), ncol = 2)
tt[1,] <- c(t1, t2)    # Save starting point
# For demonstration load pre-computed values
# Replace this with your algorithm!
# tt is a M x 2 array, with M draws of both theta_1 and theta_2
load(root("demos_ch11","demo11_2a.RData"))

#' The rest is for illustration

#' Take the first 200 draws
#' to illustrate how the sampler works
df100 <- data.frame(id=rep(1,100),
                    iter=1:100, 
                    th1 = tt[1:100, 1],
                    th2 = tt[1:100, 2],
                    th1l = c(tt[1, 1], tt[1:(100-1), 1]),
                    th2l = c(tt[1, 2], tt[1:(100-1), 2]))

#' Take the first 5000 observations after warmup of 50
S <- 5000
warm <- 500
dfs <- data.frame(th1 = tt[(warm+1):S, 1], th2 = tt[(warm+1):S, 2])
#' Remove warm-up period of 50 first draws later

# labels and frame indices for the plot
labs1 <- c('Draws', 'Steps of the sampler', '90% HPD')
p1 <- ggplot() +
  geom_jitter(data = df100, width=0.05, height=0.05,
              aes(th1, th2, group=id, color ='1'), alpha=0.3) +
  geom_segment(data = df100, aes(x = th1, xend = th1l, color = '2',
                                 y = th2, yend = th2l)) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '3'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('red', 'forestgreen','blue'), labels = labs1) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA, NA), linetype = c(0, 1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' The following generates a gif animation
#' of the steps of the sampler (might take 10 seconds).
#+ Metropolis (1), results='hide', message=FALSE
anim <- animate(p1 +   
                  transition_reveal(along=iter) + 
                  shadow_trail(0.01))

#' Show the animation
anim

#' Plot the final frame
p1

#' show 1000 draws after the warm-up
labs2 <- c('Draws', '90% HPD')
ggplot() +
  geom_point(data = dfs[1:1000,],
             aes(th1, th2, color = '1'), alpha = 0.3) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '2'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('steelblue', 'blue'), labels = labs2) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA), linetype = c(0, 1), alpha = c(1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' show 4500 draws after the warm-up
labs2 <- c('Draws', '90% HPD')
ggplot() +
  geom_point(data = dfs,
             aes(th1, th2, color = '1'), alpha = 0.3) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '2'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('steelblue', 'blue'), labels = labs2) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA), linetype = c(0, 1), alpha = c(1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' ### Convergence diagnostics
summarise_draws(dfs)
neff <- apply(dfs, 2, ess_basic)
# both theta have own neff, but for plotting these are so close to each
# other, so that single relative efficiency value is used
reff <- mean(neff/S)

#' ### Visual convergence diagnostics

#' Collapse the data frame with row numbers augmented
#' into key-value pairs for visualizing the chains
dfb <- dfs
Sb <- S-warm
dfch <- within(dfb, iter <- 1:Sb) %>% 
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' Another data frame for visualizing the estimate of
#' the autocorrelation function
nlags <- 50
dfa <- sapply(dfb, function(x) acf(x, lag.max = nlags, plot = F)$acf) %>%
  data.frame(iter = 0:(nlags)) %>% 
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' A third data frame to visualize the cumulative averages
#' and the 95% intervals
dfca <- (cumsum(dfb) / (1:Sb)) %>%
  within({iter <- 1:Sb
  uppi <-  1.96/sqrt(1:Sb)
  upp <- 1.96/(sqrt(1:Sb*reff))}) %>%
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' Visualize the chains
ggplot(data = dfch) +
  geom_line(aes(iter, value, color = grp)) +
  labs(title = 'Trends') +
  scale_color_discrete(labels = c('theta1','theta2')) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Visualize the estimate of the autocorrelation function
ggplot(data = dfa) +
  geom_line(aes(iter, value, color = grp)) +
  geom_hline(aes(yintercept = 0)) +
  labs(title = 'Autocorrelation function') +
  scale_color_discrete(labels = c('theta1', 'theta2')) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Visualize the estimate of the Monte Carlo error estimates
# labels
labs3 <- c('theta1', 'theta2',
           '95% interval for MCMC error',
           '95% interval for independent MC')
ggplot() +
  geom_line(data = dfca, aes(iter, value, color = grp, linetype = grp)) +
  geom_line(aes(1:Sb, -1.96/sqrt(1:Sb*reff)), linetype = 2) +
  geom_line(aes(1:Sb, -1.96/sqrt(1:Sb)), linetype = 3) +
  geom_hline(aes(yintercept = 0)) +
  coord_cartesian(ylim = c(-1.5, 1.5), xlim = c(0,4000)) +
  labs(title = 'Cumulative averages') +
  scale_color_manual(values = c('red','blue',rep('black', 2)), labels = labs3) +
  scale_linetype_manual(values = c(1, 1, 2, 3), labels = labs3) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Same again with r=0.99

#' Parameters of a normal distribution used as a toy target distribution
y1 <- 0
y2 <- 0
r <- 0.99
Sigma <- diag(2)
Sigma[1, 2] <- r
Sigma[2, 1] <- r
#' Metropolis proposal distribution scale
sp <- 0.3

#' Sample from the toy distribution to visualize 90% HPD
#' interval with ggplot's stat_ellipse()
dft <- data.frame(mvrnorm(100000, c(0, 0), Sigma))
#' see BDA3 p. 85 for how to compute HPD for multivariate normal
#' in 2d-case contour for 90% HPD is an ellipse, whose semimajor
#' axes can be computed from the eigenvalues of the covariance
#' matrix scaled by a value selected to get ellipse match the
#' density at the edge of 90% HPD. Angle of the ellipse could be
#' computed from the eigenvectors, but since the marginals are same
#' we know that angle is pi/4

#' Starting value of the chain
t1 <- -2.5
t2 <- 2.5
#' Number of iterations.
M <- 5000

#' Insert your own Metropolis sampling here
# Allocate memory for the sample
tt <- matrix(rep(0, 2*M), ncol = 2)
tt[1,] <- c(t1, t2)    # Save starting point
# For demonstration load pre-computed values
# Replace this with your algorithm!
# tt is a M x 2 array, with M draws of both theta_1 and theta_2
load(root("demos_ch11","demo11_2b.RData"))

#' The rest is for illustration

#' Take the first 200 draws
#' to illustrate how the sampler works
df100 <- data.frame(id=rep(1,100),
                    iter=1:100, 
                    th1 = tt[1:100, 1],
                    th2 = tt[1:100, 2],
                    th1l = c(tt[1, 1], tt[1:(100-1), 1]),
                    th2l = c(tt[1, 2], tt[1:(100-1), 2]))

#' Take the first 5000 observations after warmup of 50
S <- 5000
warm <- 500
dfs <- data.frame(th1 = tt[(warm+1):S, 1], th2 = tt[(warm+1):S, 2])
#' Remove warm-up period of 50 first draws later

# labels and frame indices for the plot
labs1 <- c('Draws', 'Steps of the sampler', '90% HPD')
p1 <- ggplot() +
  geom_jitter(data = df100, width=0.05, height=0.05,
             aes(th1, th2, group=id, color ='1'), alpha=0.3) +
  geom_segment(data = df100, aes(x = th1, xend = th1l, color = '2',
                                 y = th2, yend = th2l)) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '3'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('red', 'forestgreen','blue'), labels = labs1) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA, NA), linetype = c(0, 1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' The following generates a gif animation
#' of the steps of the sampler (might take 10 seconds).
#+ Metropolis (2), results='hide', message=FALSE
anim <- animate(p1 +   
                  transition_reveal(along=iter) + 
                  shadow_trail(0.01))

#' Show the animation
anim

#' Plot the final frame
p1

#' show 1000 draws after the warm-up
labs2 <- c('Draws', '90% HPD')
ggplot() +
  geom_point(data = dfs[1:1000,],
             aes(th1, th2, color = '1'), alpha = 0.3) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '2'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('steelblue', 'blue'), labels = labs2) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA), linetype = c(0, 1), alpha = c(1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' show 4500 draws after the warm-up
labs2 <- c('Draws', '90% HPD')
ggplot() +
  geom_point(data = dfs,
             aes(th1, th2, color = '1'), alpha = 0.3) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '2'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('steelblue', 'blue'), labels = labs2) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA), linetype = c(0, 1), alpha = c(1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' ### Convergence diagnostics
summarise_draws(dfs)
neff <- apply(dfs, 2, ess_basic)
# both theta have own neff, but for plotting these are so close to each
# other, so that single relative efficiency value is used
reff <- mean(neff/S)

#' ### Visual convergence diagnostics

#' Collapse the data frame with row numbers augmented
#' into key-value pairs for visualizing the chains
dfb <- dfs
Sb <- S-warm
dfch <- within(dfb, iter <- 1:Sb) %>% 
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' Another data frame for visualizing the estimate of
#' the autocorrelation function
nlags <- 100
dfa <- sapply(dfb, function(x) acf(x, lag.max = nlags, plot = F)$acf) %>%
  data.frame(iter = 0:(nlags)) %>% 
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' A third data frame to visualize the cumulative averages
#' and the 95% intervals
dfca <- (cumsum(dfb) / (1:Sb)) %>%
  within({iter <- 1:Sb
          uppi <-  1.96/sqrt(1:Sb)
          upp <- 1.96/(sqrt(1:Sb*reff))}) %>%
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' Visualize the chains
ggplot(data = dfch) +
  geom_line(aes(iter, value, color = grp)) +
  labs(title = 'Trends') +
  scale_color_discrete(labels = c('theta1','theta2')) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Visualize the estimate of the autocorrelation function
ggplot(data = dfa) +
  geom_line(aes(iter, value, color = grp)) +
  geom_hline(aes(yintercept = 0)) +
  labs(title = 'Autocorrelation function') +
  scale_color_discrete(labels = c('theta1', 'theta2')) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Visualize the estimate of the Monte Carlo error estimates
# labels
labs3 <- c('theta1', 'theta2',
           '95% interval for MCMC error',
           '95% interval for independent MC')
ggplot() +
  geom_line(data = dfca, aes(iter, value, color = grp, linetype = grp)) +
  geom_line(aes(1:Sb, -1.96/sqrt(1:Sb*reff)), linetype = 2) +
  geom_line(aes(1:Sb, -1.96/sqrt(1:Sb)), linetype = 3) +
  geom_hline(aes(yintercept = 0)) +
  coord_cartesian(ylim = c(-1.5, 1.5), xlim = c(0,4000)) +
  labs(title = 'Cumulative averages') +
  scale_color_manual(values = c('red','blue',rep('black', 2)), labels = labs3) +
  scale_linetype_manual(values = c(1, 1, 2, 3), labels = labs3) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Same again with sp = 1.5
sp = 1.5

#' Insert your own Metropolis sampling here
# Allocate memory for the sample
tt <- matrix(rep(0, 2*M), ncol = 2)
tt[1,] <- c(t1, t2)    # Save starting point
# For demonstration load pre-computed values
# Replace this with your algorithm!
# tt is a M x 2 array, with M draws of both theta_1 and theta_2
load(root("demos_ch11","demo11_2c.RData"))

#' The rest is for illustration

#' Take the first 200 draws
#' to illustrate how the sampler works
df100 <- data.frame(id=rep(1,100),
                    iter=1:100, 
                    th1 = tt[1:100, 1],
                    th2 = tt[1:100, 2],
                    th1l = c(tt[1, 1], tt[1:(100-1), 1]),
                    th2l = c(tt[1, 2], tt[1:(100-1), 2]))

#' Take the first 5000 observations after warmup of 50
S <- 5000
warm <- 500
dfs <- data.frame(th1 = tt[(warm+1):S, 1], th2 = tt[(warm+1):S, 2])
#' Remove warm-up period of 50 first draws later

# labels and frame indices for the plot
labs1 <- c('Draws', 'Steps of the sampler', '90% HPD')
p1 <- ggplot() +
  geom_jitter(data = df100, width=0.05, height=0.05,
             aes(th1, th2, group=id, color ='1'), alpha=0.3) +
  geom_segment(data = df100, aes(x = th1, xend = th1l, color = '2',
                                 y = th2, yend = th2l)) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '3'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('red', 'forestgreen','blue'), labels = labs1) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA, NA), linetype = c(0, 1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' The following generates a gif animation
#' of the steps of the sampler (might take 10 seconds).
#+ Metropolis (3), results='hide', message=FALSE
anim <- animate(p1 +   
                  transition_reveal(along=iter) + 
                  shadow_trail(0.01))

#' Show the animation
anim

#' show 1000 draws after the warm-up
labs2 <- c('Draws', '90% HPD')
ggplot() +
  geom_point(data = dfs[1:1000,],
             aes(th1, th2, color = '1'), alpha = 0.3) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '2'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('steelblue', 'blue'), labels = labs2) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA), linetype = c(0, 1), alpha = c(1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' show 4500 draws after the warm-up
labs2 <- c('Draws', '90% HPD')
ggplot() +
  geom_point(data = dfs,
             aes(th1, th2, color = '1'), alpha = 0.3) +
  stat_ellipse(data = dft, aes(x = X1, y = X2, color = '2'), level = 0.9) +
  coord_cartesian(xlim = c(-4, 4), ylim = c(-4, 4)) +
  labs(x = 'theta1', y = 'theta2') +
  scale_color_manual(values = c('steelblue', 'blue'), labels = labs2) +
  guides(color = guide_legend(override.aes = list(
    shape = c(16, NA), linetype = c(0, 1), alpha = c(1, 1)))) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' ### Convergence diagnostics
summarise_draws(dfs)
neff <- apply(dfs, 2, ess_basic)
# both theta have own neff, but for plotting these are so close to each
# other, so that single relative efficiency value is used
reff <- mean(neff/S)

#' ### Visual convergence diagnostics

#' Collapse the data frame with row numbers augmented
#' into key-value pairs for visualizing the chains
dfb <- dfs
Sb <- S-warm
dfch <- within(dfb, iter <- 1:Sb) %>% 
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' Another data frame for visualizing the estimate of
#' the autocorrelation function
nlags <- 100
dfa <- sapply(dfb, function(x) acf(x, lag.max = nlags, plot = F)$acf) %>%
  data.frame(iter = 0:(nlags)) %>% 
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' A third data frame to visualize the cumulative averages
#' and the 95% intervals
dfca <- (cumsum(dfb) / (1:Sb)) %>%
  within({iter <- 1:Sb
          uppi <-  1.96/sqrt(1:Sb)
          upp <- 1.96/(sqrt(1:Sb*reff))}) %>%
  pivot_longer(cols = !iter, names_to = "grp", values_to = "value")

#' Visualize the chains
ggplot(data = dfch) +
  geom_line(aes(iter, value, color = grp)) +
  labs(title = 'Trends') +
  scale_color_discrete(labels = c('theta1','theta2')) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Visualize the estimate of the autocorrelation function
ggplot(data = dfa) +
  geom_line(aes(iter, value, color = grp)) +
  geom_hline(aes(yintercept = 0)) +
  labs(title = 'Autocorrelation function') +
  scale_color_discrete(labels = c('theta1', 'theta2')) +
  theme(legend.position = 'bottom', legend.title = element_blank())

#' Visualize the estimate of the Monte Carlo error estimates
# labels
labs3 <- c('theta1', 'theta2',
           '95% interval for MCMC error',
           '95% interval for independent MC')
ggplot() +
  geom_line(data = dfca, aes(iter, value, color = grp, linetype = grp)) +
  geom_line(aes(1:Sb, -1.96/sqrt(1:Sb*reff)), linetype = 2) +
  geom_line(aes(1:Sb, -1.96/sqrt(1:Sb)), linetype = 3) +
  geom_hline(aes(yintercept = 0)) +
  coord_cartesian(ylim = c(-1.5, 1.5), xlim = c(0,4000)) +
  labs(title = 'Cumulative averages') +
  scale_color_manual(values = c('red','blue',rep('black', 2)), labels = labs3) +
  scale_linetype_manual(values = c(1, 1, 2, 3), labels = labs3) +
  theme(legend.position = 'bottom', legend.title = element_blank())
