#設定
library(knitr)
library(tidyverse)
library(lubridate)
library(mclust)
library(factoextra)
library(corrplot)
library(plotly)
setwd("C:\\Users\\stat-pc\\Desktop\\GraduateCourse\\Statistical Computation\\midterm")
rawdata = read.csv("OnlineRetail.csv", header = T, stringsAsFactors = F)
data = rawdata %>% filter((!is.na(CustomerID)) & (Quantity >=0))

#資料前處理
mon = data %>% mutate(total = Quantity*UnitPrice) %>% group_by(CustomerID) %>% summarize(Monetary = sum(total))
data$InvoiceDate = parse_date_time(data$InvoiceDate, order = "%d-%m-%Y %H:%M")
fre = data %>% group_by(CustomerID) %>% summarize(Frequency = n_distinct(InvoiceNo))
maxdate = Sys.Date()
rec = data %>% mutate(date_diff = as.numeric(difftime(maxdate, InvoiceDate, units = "day"))) %>% group_by(CustomerID) %>% summarise(Recency = min(date_diff))
rfm = rec %>% inner_join(fre, by = "CustomerID") %>% inner_join(mon, by = "CustomerID") 
rfm_model_out = rfm %>% remove_rownames %>% column_to_rownames(var="CustomerID")
rfm_model_out = rfm_model_out[-which(rfm_model_out$Monetary==0),]

# EDA
plot_ly(x=rfm_model_out$Recency , y=rfm_model_out$Frequency, z=rfm_model_out$Monetary, type="scatter3d", mode="markers")
rfm_gather = rfm_model_out %>% gather()
ggplot(rfm_gather, aes(x = value)) + geom_histogram() + facet_wrap(.~key, scales = "free")
ggplot(rfm_gather, aes(x = value)) + geom_boxplot() + facet_wrap(.~key, scales = "free") + coord_flip()
pairs(rfm_model_out)
ggplot(rfm_gather, aes(sample = value)) + facet_wrap(.~key, scales = "free") + stat_qq()+stat_qq_line()
rfm_model_out_log = rfm_model_out %>% mutate_all(log)
plot_ly(x=rfm_model_out_log$Recency , y=rfm_model_out_log$Frequency, z=rfm_model_out_log$Monetary, type="scatter3d", mode="markers")
rfm_gather = rfm_model_out_log %>% gather()
ggplot(rfm_gather, aes(x = value)) + geom_histogram() + facet_wrap(.~key, scales = "free")
ggplot(rfm_gather, aes(x = value)) + geom_boxplot() + facet_wrap(.~key, scales = "free") + coord_flip()
pairs(rfm_model_out_log)
corrplot(cor(rfm_model_out_log))
ggplot(rfm_gather, aes(sample = value)) + facet_wrap(.~key, scales = "free") + stat_qq()+stat_qq_line()

#Simulation
gibbs<-function (n, rho,mu) 
{
  mat <- matrix(ncol = 3, nrow = n)
  mat[1, ] <- mu
  for (i in 2:n) {
    x <- rnorm(1, mu[1]+rho[2:3,1]%*%solve(rho[2:3,2:3])%*%(mat[i-1,2:3]-mu[2:3]), sqrt(rho[1,1]-rho[1,2:3]%*%solve(rho[2:3,2:3])%*%rho[1,2:3]))
    y <- rnorm(1, mu[2]+rho[c(1,3),2]%*%solve(rho[c(1,3),c(1,3)])%*%(mat[i-1,c(1,3)]-mu[c(1,3)]), sqrt(rho[2,2]-rho[2,c(1,3)]%*%solve(rho[c(1,3),c(1,3)])%*%rho[2,c(1,3)]))
    z = rnorm(1, mu[3]+rho[1:2,3]%*%solve(rho[1:2,1:2])%*%(mat[i-1,1:2]-mu[1:2]), sqrt(rho[3,3]-rho[3,1:2]%*%solve(rho[1:2,1:2])%*%rho[3,1:2]))
    mat[i, ] <- c(x, y, z)
  }
  mat
}
rho = runif(6)
sigma1 = matrix(c(1,rho[1],rho[2],rho[1],2,rho[3],rho[2],rho[3],3), nrow = 3, ncol = 3)
mu1 = matrix(c(1,1,0),nrow = 3, ncol = 1)
sigma2 = matrix(c(2,rho[4],rho[5],rho[4],3,rho[6],rho[5],rho[4],1), nrow = 3, ncol = 3)
mu2 = matrix(c(1,0,1),nrow = 3, ncol = 1)
num = 1000
norm1 = gibbs(num, sigma1, mu1)
norm2 = gibbs(num, sigma2, mu2)
statistical_distance = function(data){
  y = data.frame(data) %>% mutate_all(function(x){x-mean(x)}) %>% data.matrix()
  ans = diag(y%*%solve(cov(y))%*%t(y))
  return(ans)
}
QQplot_chi = function(data){
  df = ncol(data)
  ans = statistical_distance(data)
  car::qqPlot(ans, dist = "chisq", df = df, ylab = "Sample Quantiles", main = 'chi-squared Q-Q plot for statistical distance')
}
QQplot_chi(norm1)
QQplot_chi(norm2)

temp = matrix(ncol = 3, nrow = num)
group = c()
for(i in 1:num){
  x = runif(1)
  if(x<0.4){
    temp[i,] = norm1[i,]
    group = c(group, 1)
  }else{
    temp[i,] = norm2[i,]
    group = c(group,2)
  }
}
sim_exp = exp(temp)
plot_ly(x=sim_exp[,1] , y=sim_exp[,2], z=sim_exp[,3], type="scatter3d", mode="markers", color = as.factor(group))
pairs(sim_exp,col = as.factor(group))
mod = Mclust(sim_exp, G = 2)
plot.Mclust(mod, what = "classification", main = F, addEllipses = F)
plot_ly(x=sim_exp[,1] , y=sim_exp[,2], z=sim_exp[,3], type="scatter3d", mode="markers", color = as.factor(mod$classification))
pairs(sim_exp, col = mod$classification, pch = 19, main = "K-means")
title(main = "GMM")
mod = kmeans(sim_exp, centers = 2)
pairs(sim_exp, col = mod$cluster, pch = 19, main = "K-means")
plot_ly(x=sim_exp[,1] , y=sim_exp[,2], z=sim_exp[,3], type="scatter3d", mode="markers", color = as.factor(mod$cluster))

gmm_accu = c()
k_accu = c()
for(i in 1:1000){
  num = 1000
  norm1 = gibbs(num, sigma1, mu1)
  norm2 = gibbs(num, sigma2, mu2)
  temp = matrix(ncol = 3, nrow = num)
  group = c()
  for(i in 1:num){
    x = runif(1)
    if(x<0.4){
      temp[i,] = norm1[i,]
      group = c(group, 1)
    }else {
      temp[i,] = norm2[i,]
      group = c(group, 2)
    }
  }
  sim_exp = exp(temp)
  gmm = Mclust(sim_exp, G = 2)
  temp = sum(group == gmm$classification)/1000
  if(temp <= 0.5){
    gmm_accu = c(gmm_accu, 1-temp)
  }else{
    gmm_accu = c(gmm_accu, temp)
  }
  kmod = kmeans(sim_exp, centers = 2)
  temp = sum(group==kmod$cluster)/1000
  if(temp <= 0.5){
    k_accu = c(k_accu, 1-temp)
  }else{
    k_accu = c(k_accu, temp)
  }
}
par(mfrow = c(1,2))
boxplot(gmm_accu, xlab = "GMM")
boxplot(k_accu, xlab = "K-means")

sim = log(sim_exp)
plot_ly(x=sim[,1] , y=sim[,2], z=sim[,3], type="scatter3d", mode="markers", color = as.factor(group))
pairs(sim,col = as.factor(group))
mod = Mclust(sim, G = 2)
plot.Mclust(mod, what = "classification", main = F, addEllipses = F)
plot_ly(x=sim[,1] , y=sim[,2], z=sim[,3], type="scatter3d", mode="markers", color = as.factor(mod$classification))
mod = kmeans(sim, centers = 2)
pairs(sim, col = mod$cluster, pch = 19, main = "K-means")
plot_ly(x=sim[,1] , y=sim[,2], z=sim[,3], type="scatter3d", mode="markers", color = as.factor(mod$cluster))

gmm_accu = c()
k_accu = c()
for(i in 1:1000){
  num = 1000
  norm1 = gibbs(num, sigma1, mu1)
  norm2 = gibbs(num, sigma2, mu2)
  temp = matrix(ncol = 3, nrow = num)
  group = c()
  for(i in 1:num){
    x = runif(1)
    if(x<0.4){
      temp[i,] = norm1[i,]
      group = c(group, 1)
    }else{
      temp[i,] = norm2[i,]
      group = c(group, 2)
    }
  }
  sim = temp
  gmm = Mclust(sim, G = 2)
  temp = sum(group == gmm$classification)/1000
  if(temp <= 0.5){
    gmm_accu = c(gmm_accu, 1-temp)
  }else{
    gmm_accu = c(gmm_accu, temp)
  }
  kmod = kmeans(sim_exp, centers = 2)
  temp = sum(group==kmod$cluster)/1000
  if(temp <= 0.5){
    k_accu = c(k_accu, 1-temp)
  }else{
    k_accu = c(k_accu, temp)
  }
}
par(mfrow = c(1,2))
boxplot(gmm_accu, xlab = "GMM")
boxplot(k_accu, xlab = "K-means")

# Case study
# k-means
fviz_nbclust(rfm_model_out, FUNcluster = kmeans, method = "wss")
mod = kmeans(rfm_model_out, centers = 3)
pairs(rfm_model_out, col = mod$cluster, pch = 19)
fviz_nbclust(rfm_model_out_log, FUNcluster = kmeans, method = "wss")
mod = kmeans(rfm_model_out_log, centers = 3)
pairs(rfm_model_out_log, col = mod$cluster, pch = 19)
rfm_box = cbind(rfm_model_out_log, mod$cluster) %>% mutate(Cluster = as.factor(mod$cluster))
ggplot(rfm_box, aes(x = Cluster, y = Recency, group = Cluster, fill = Cluster)) + geom_boxplot() + scale_fill_brewer(palette="Pastel1")
ggplot(rfm_box, aes(x = Cluster, y = Frequency, group = Cluster, fill = Cluster)) + geom_boxplot() + scale_fill_brewer(palette="Pastel1")
ggplot(rfm_box, aes(x = Cluster, y = Monetary, group = Cluster, fill = Cluster)) + geom_boxplot() + scale_fill_brewer(palette="Pastel1")
plot_ly(x=rfm_model_out_log$Recency , y=rfm_model_out_log$Frequency, z=rfm_model_out_log$Monetary, type="scatter3d", mode="markers", color = as.factor(mod$cluster))
plot_ly(x=rfm_model_out$Recency , y=rfm_model_out$Frequency, z=rfm_model_out$Monetary, type="scatter3d", mode="markers", color = as.factor(mod$cluster))


# GMM
mod = Mclust(rfm_model_out, G = 1:25)
plot.Mclust(mod, what = "BIC")
abline(v = 6, lty = 8)
mod = Mclust(rfm_model_out, G = 6)
plot.Mclust(mod, what = "classification",addEllipses = F)
rfm_box = cbind(rfm_model_out, mod$classification) %>% mutate(Cluster = as.factor(mod$classification))
ggplot(rfm_box, aes(x = Cluster, y = Recency, group = Cluster, fill = Cluster)) + geom_boxplot() + scale_fill_brewer(palette="Paired")
ggplot(rfm_box, aes(x = Cluster, y = Frequency, group = Cluster, fill = Cluster)) + geom_boxplot() + scale_fill_brewer(palette="Paired") + scale_y_log10()
ggplot(rfm_box, aes(x = Cluster, y = Monetary, group = Cluster, fill = Cluster)) + geom_boxplot() + scale_fill_brewer(palette="Paired") + scale_y_log10()
mod = Mclust(rfm_model_out_log, G = 1:25)
plot.Mclust(mod, what = "BIC")
plot.Mclust(mod, what = "classification",addEllipses = F)
plot_ly(x=rfm_model_out$Recency , y=rfm_model_out$Frequency, z=rfm_model_out$Monetary, type="scatter3d", mode="markers", color = as.factor(mod$classification))
plot_ly(x=rfm_model_out_log$Recency , y=rfm_model_out_log$Frequency, z=rfm_model_out_log$Monetary, type="scatter3d", mode="markers", color = as.factor(mod$classification))

