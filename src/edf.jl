include("fonctions.jl")
include("Estim_WienerARD1_functions_revised.jl")

chemin_données = "/home/AD/faidy/JuliaStatsProject/data/real_data/"
chemin_projet = "/home/AD/faidy/JuliaStatsProject/"

# Transformer le contenu de la feuille de IND-COL-1.xls en une matrice
data_matrix_ind_col1 = readxlsheet(string(chemin_données, "Données_EDF_240611/Colmatage/IND-COL-1.xls"), "IND-COL-1")

# Transformer le contenu de la feuille de IND-COL-2.xls en une matrice
data_matrix_ind_col2 = readxlsheet(string(chemin_données, "Données_EDF_240611/Colmatage/IND-COL-2.xls"), "IND-COL-2")

# Les cases vides de la colonne VALEUR des fichiers IND-COL-1.xls et IND-COL-2.xls ont été remplis par un objet DataValue{Union{}} 
# qu'on le remplace par l'objet missing qui représente une donnée manquante en Julia
isNA(x) = typeof(x) == DataValue{Union{}}
valeurs = replace( x -> isNA(x) ? missing : x, data_matrix_ind_col1)

data_matrix_ind_col1 = replace( x -> isNA(x) ? missing : x, data_matrix_ind_col1)
data_matrix_ind_col2 = replace( x -> isNA(x) ? missing : x, data_matrix_ind_col2)

df1 = MatrixToDataFrame(data_matrix_ind_col1)
df1 = dropmissing(df1, :VALEUR)

df2 = MatrixToDataFrame(data_matrix_ind_col2)
df2 = dropmissing(df2, :VALEUR)

nettoyages = readxlsheet(string(chemin_données, "Données_EDF_240611/Nettoyages/NETTOYAGES.xls"), "NETTOYAGES")
df_nettoyages = MatrixToDataFrame(nettoyages)

df_Infos_gen = readxlsheet(string(chemin_données, "Données_EDF_240611/Informations générales 9-7/HEURES.xls"), "HEURES")
df_Infos_gen = MatrixToDataFrame(df_Infos_gen)

df_carac = readxlsheet(string(chemin_données, "Données_EDF_240611/Informations générales 16-07/CARACTERISTIQUES_GV.xls"), "&_RETD004Export")
df_carac = MatrixToDataFrame(df_carac)
df_carac = df_carac[:, [:REFERENCE, :REFERENCE2]]
df_carac = unique(df_carac)

# Création des enfants
U2 = NAryTreeNode(missing, "U2", Vector{NAryTreeNode}())
U3 = NAryTreeNode(missing, "U3", Vector{NAryTreeNode}())
U5 = NAryTreeNode(missing, "U5", Vector{NAryTreeNode}())
U9 = NAryTreeNode(missing, "U9", Vector{NAryTreeNode}())
U10 = NAryTreeNode(missing, "U10", Vector{NAryTreeNode}())
U18 = NAryTreeNode(missing, "U18", Vector{NAryTreeNode}())
U19 = NAryTreeNode(missing, "U19", Vector{NAryTreeNode}())
U8 = NAryTreeNode(missing, "U8", Vector{NAryTreeNode}())
U13 = NAryTreeNode(missing, "U13", Vector{NAryTreeNode}())

# Création du parent avec les enfants
P1 = NAryTreeNode(missing, "P1", Vector([U2, U3, U5, U9, U10, U18, U19, U8, U13]))
# Mettre à jour les parents des enfants
for child in P1.children
    child.parent = P1
end

# Création des enfants
U1 = NAryTreeNode(missing, "U1", Vector{NAryTreeNode}())
U4 = NAryTreeNode(missing, "U4", Vector{NAryTreeNode}())
U11 = NAryTreeNode(missing, "U11", Vector{NAryTreeNode}())
U12 = NAryTreeNode(missing, "U12", Vector{NAryTreeNode}())
U14 = NAryTreeNode(missing, "U14", Vector{NAryTreeNode}())
U15 = NAryTreeNode(missing, "U15", Vector{NAryTreeNode}())
U16 = NAryTreeNode(missing, "U16", Vector{NAryTreeNode}())
U17 = NAryTreeNode(missing, "U17", Vector{NAryTreeNode}())

# Création du parent avec les enfants
P2 = NAryTreeNode(missing, "P2", Vector([U1, U4, U11, U12, U14, U15, U16, U17]))

# Mettre à jour les parents des enfants
for child in P2.children
    child.parent = P2
end

# Création des enfants
U6 = NAryTreeNode(missing, "U6", Vector{NAryTreeNode}())
U7 = NAryTreeNode(missing, "U7", Vector{NAryTreeNode}())

# Création du parent avec les enfants
P3 = NAryTreeNode(missing, "P3", Vector([U6, U7]))

# Mettre à jour les parents des enfants
for child in P3.children
    child.parent = P3
end

paliers = [P1, P2, P3]

for palier in paliers
    unites = palier.children
    for unite in unites
        sous_unites = Vector(unique(df_Infos_gen[df_Infos_gen.UNITE .== unite.value, :].SOUS_UNITE))
        for sous_unite in sous_unites
            push!(unite.children, NAryTreeNode(unite, sous_unite, Vector{NAryTreeNode}()))
        end
    end
end

for palier in paliers
    unites = palier.children
    for unite in unites
        sous_unites = unite.children
        for sous_unite in sous_unites
            push!(sous_unite.children, NAryTreeNode(sous_unite, "avant_RGV", Vector{NAryTreeNode}()))
            push!(sous_unite.children, NAryTreeNode(sous_unite, "apres_RGV", Vector{NAryTreeNode}()))
        end
    end
end

for palier in paliers
    unites = palier.children
    for unite in unites
        sous_unites = unite.children
        for sous_unite in sous_unites
            data_sous_unite_avant = filter(row -> row.UNITE .== unite.value 
                                    && row.SOUS_UNITE .== sous_unite.value
                                    && row[10] .== "ORIGINE",
                                 df_Infos_gen)
            data_sous_unite_apres = filter(row -> row.UNITE .== unite.value 
                                    && row.SOUS_UNITE .== sous_unite.value
                                    && row[10] .== "Remplacement",
                                    df_Infos_gen)
            circuits_avant = unique(data_sous_unite_avant.CIRCUIT)
            circuits_apres = unique(data_sous_unite_apres.CIRCUIT)
            for etat in sous_unite.children
                if etat.value == "avant_RGV"
                    for circuit in circuits_avant
                        push!(etat.children, NAryTreeNode(etat, circuit, Vector{NAryTreeNode}()))
                    end
                else
                    for circuit in circuits_apres
                        push!(etat.children, NAryTreeNode(etat, circuit, Vector{NAryTreeNode}()))
                    end
                end
            end
        end
    end
end


# Spécifiez le chemin complet de votre répertoire
directory = string(chemin_données, "Données_EDF_240611/Encrassement 2-7/")

# Utilisez readdir() pour obtenir les noms des fichiers et des sous-répertoires
files = readdir(directory)

# Filtrer les fichiers pour ne garder que ceux qui ont l'extension .xlsx
xlsx_files = filter(file -> endswith(file, ".xlsx"), files)
xlsx_files = [file for file in xlsx_files if file != "~\$PERFOS_U2S4_3,48-3,47-3,49.xlsx" && file != "~\$PERFOS_U19S2_2,45-2,43-2,44.xlsx"]

GVs_dict = set_GVs_dict(paliers)

plot(GVs_dict[2.83].IND_COL_3.HEURES_MAT, GVs_dict[2.83].IND_COL_3.C2_IND_COL_3)
scatter!(GVs_dict[2.83].IND_COL_3.HEURES_MAT, GVs_dict[2.83].IND_COL_3.C2_IND_COL_3)
vline!(GVs_dict[2.83].maintenances.HEURES_MAT, color=:red)
obs = GVs_dict[2.83].IND_COL_3.C2_IND_COL_3
times = GVs_dict[2.83].IND_COL_3.HEURES_MAT
insert!(obs, 1, 0.)
insert!(times, 1, 0.)

obs = obs[2:end]
times = times[2:end]

obs = [x isa Number ? Float64(x) : tryparse(Float64, x) for x in obs]
times = [x isa Number ? Float64(x) : tryparse(Float64, x) for x in times]
delta_t = delta2(2, [times[1:30], times[31:57], times[58:end]])
k = 2
sum(times .< GVs_dict[2.83].maintenances.HEURES_MAT[1])
obsVect = [obs[1:29], obs[30:56], obs[57:end]]

rho = estimateur_rho_chapeau_revised(k, obsVect, delta_t)
s2 = sigma2_chapeau_revised(rho, k, obsVect, delta_t)
mu = mu_chapeau_revised(rho, k, obsVect, delta_t)
delta_t

GVs_dict[2.83].maintenances.HEURES_MAT
psARD1 = WienerARD1(mu, s2, 1., 130000, rho, [83877.0, 119225.0] )
simulate!(psARD1)

plot()
plot!(psARD1)
plot!(psARD1.underlying_process)
scatter!(times, obs)
savefig("essai_edf_U3_S5")
while true
    psARD1 = WienerARD1(mu, s2, 1., 130000, rho, [83877.0, 119225.0] )
    simulate!(psARD1)

    v = []
    for temps in times
        for (pos, vect) in enumerate(psARD1.new_times)
            index = findfirst(t -> abs(t-temps) < 1, vect)
            if !isnothing(index)
                push!(v, (pos, index))
                break
            end
        end
    end

    sim = [psARD1.values[pos][index] for (pos, index) in v]

    # println(length(sim))
    if sum(abs.(sim -  obs)).<1
        break
    end
end

