include("fonctions.jl")

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

# Afficher l'arbre à partir des paliers
print_tree_from_paliers(paliers, "arbre.txt")

circuit_shapes = Dict{String, Symbol}()
# coder le numéro de circuit en forme géométrique
circuit_shapes["C1"]= :circle
circuit_shapes["C2"]= :diamond
circuit_shapes["C3"]= :rect
circuit_shapes["C4"]= :star5

circuit_enc_colors = Dict{String, Symbol}()

circuit_enc_colors["C1"]= :pink
circuit_enc_colors["C2"]= :purple
circuit_enc_colors["C3"]= :grey
circuit_enc_colors["C4"]= :magenta

for palier in paliers
    for unite in palier.children
        for sous_unite in unite.children
            plot(sous_unite)
        end
    end
end

