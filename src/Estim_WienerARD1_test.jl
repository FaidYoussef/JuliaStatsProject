include("Estim_WienerARD1_functions_revised.jl")


mu = 2.0
sigma2 = 5.0
timestep = 2.
steps = 15
rho = 0.7
maintenance_times = [ 1. * i for i in 6:6:27]
estimations_rho = []
estimations_rho_revised = []
estimations_mu = []
estimations_mu_revised = []
estimations_sigma2 = []
estimations_sigma2_revised = []

psARD1 = WienerARD1(mu, sigma2, timestep, steps, rho, maintenance_times)
simulate!(psARD1)
plot()
plot!(psARD1.underlying_process)
plot!(psARD1)
observations, times = observations_sampling(psARD1, 1)
for i in 1:psARD1.k+1
    scatter!(times[i], observations[i], markersize = 3, label = false, color=:blue)
end
plot!()
savefig("ARD1 $steps.png")
for i in 1:5000
    # Créer une instance de WienerProcess
    psARD1 = WienerARD1(mu, sigma2, timestep, steps, rho, maintenance_times)
    simulate!(psARD1)
    delta_t = delta2(length(maintenance_times), psARD1.new_times)
    observations, times = observations_sampling(psARD1, 1)
    r2 = estimateur_rho_chapeau_revised(psARD1.k, observations, delta2(length(maintenance_times), times))
    push!(estimations_rho_revised, r2)
    push!(estimations_mu_revised, mu_chapeau_revised(r2, psARD1.k, observations, delta2(length(maintenance_times), times)))
    push!(estimations_sigma2_revised, sigma2_chapeau_revised(r2, psARD1.k, observations, delta2(length(maintenance_times), times)))
end
# Simuler le processus de Wiener avec les temps de maintenance

# Calcul de la moyenne et de l'écart-type
mean_estimation = mean(estimations_rho_revised)
std_estimation = std(estimations_rho_revised)

# Créer l'histogramme et ajouter la légende avec la moyenne et l'écart-type
histogram(estimations_rho_revised, bins=0:0.1:1, xlabel="Estimations", ylabel="Fréquence", title="Histogramme des estimations de rho", xlims=(0, 1),
          label="Moyenne = $(round(mean_estimation, digits=2)), Écart-type = $(round(std_estimation, digits=2))", legendfontsize=12)
savefig("estimations_rho $steps.png")

# Calcul de la moyenne et de l'écart-type
mean_estimation = mean(estimations_mu_revised)
std_estimation = std(estimations_mu_revised)
estimations_mu_revised
# Créer l'histogramme et ajouter la légende avec la moyenne et l'écart-type
histogram(estimations_mu_revised, bins = 0:0.5:5, xlabel="Estimations", ylabel="Fréquence", title="Histogramme des estimations de mu",
          label="Moyenne = $(round(mean_estimation, digits=2)), Écart-type = $(round(std_estimation, digits=2))", legendfontsize=12)
savefig("estimations_mu $steps.png")
# Afficher le plot
plot!()


# Calcul de la moyenne et de l'écart-type
mean_estimation = mean(estimations_sigma2_revised)
std_estimation = std(estimations_sigma2_revised)

# Créer l'histogramme et ajouter la légende avec la moyenne et l'écart-type
histogram(estimations_sigma2_revised, bins = 0:1:10, xlabel="Estimations", ylabel="Fréquence", title="Histogramme des estimations de sigma2",
          label="Moyenne = $(round(mean_estimation, digits=2)), Écart-type = $(round(std_estimation, digits=2))", legendfontsize=12)
savefig("estimations_sigma2 $steps.png")
# Afficher le plot
plot!()


