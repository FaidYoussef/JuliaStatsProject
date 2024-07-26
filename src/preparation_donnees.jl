using DataFrames
using ExcelReaders
using Plots
using DataValues
using XLSX
using Statistics
using Tables
import Plots: plot!, vline!, plot
using Printf

"""
Convertit une matrice en un DataFrame. La fonction prend en entrée une matrice où la première ligne contient les noms des colonnes,
et les lignes suivantes contiennent les données.

# Arguments
- `mat::Matrix{T}`: Une matrice de type `T`, où `T` peut être n'importe quel type de données supporté. La première ligne de la matrice est utilisée
  pour les noms de colonnes du DataFrame, tandis que les lignes suivantes sont les données du DataFrame.

# Returns
- `DataFrame`: Un DataFrame contenant les données de la matrice. Les noms des colonnes sont pris à partir de la première ligne de la matrice,
  et les données proviennent des lignes suivantes.
"""

function MatrixToDataFrame(mat)
    DF_mat = DataFrame(
        mat[2:end, 1:end],
        string.(mat[1, 1:end])
    )
    return DF_mat
end


"""
Convertit une matrice en deux DataFrames en fonction du circuit spécifié. La fonction extrait des colonnes spécifiques de la matrice
et crée deux DataFrames : `df_enc` pour les données d'encrassement et `df_ind_col_3` pour les données associées à la colonne `IND_COL_3`.

# Arguments
- `mat::Matrix{T}`: Une matrice de type `T`, où `T` est un type de données supporté. La matrice doit contenir au moins 3 lignes et les colonnes
  nécessaires pour extraire les données selon le circuit spécifié.
- `circuit::String`: Une chaîne de caractères indiquant le circuit à utiliser. Les valeurs acceptées sont "C1", "C2", "C3" et "C4".

# Returns
- `df_enc::DataFrame`: Un DataFrame contenant les données d'encrassement. Les colonnes sont nommées en fonction des valeurs de la matrice et du circuit.
- `df_ind_col_3::DataFrame`: Un DataFrame contenant les données associées à la colonne `IND_COL_3`. Les colonnes sont également nommées en fonction
  des valeurs de la matrice et du circuit.
"""

function IND_COL_3_and_EncMatToDataFrame(mat, circuit::String)
    # Extraire les noms des colonnes
    column_names = [mat[1,1],"$(mat[2,3])_ENC", "$(mat[2,4])_ENC", "$(mat[2,5])_ENC", "$(mat[2,6])_ENC", "$(mat[2,15])_IND_COL_3", "$(mat[2,16])_IND_COL_3", "$(mat[2,17])_IND_COL_3", "$(mat[2,18])_IND_COL_3"]

    # Créer un DataFrame à partir des données extraites
    df_enc = DataFrame()
    df_ind_col_3 = DataFrame()

    # Ajouter les données au DataFrame
    df_enc[!, column_names[1]] = mat[3:end,1]

    if circuit == "C1"
        df_enc[!, column_names[2]] = mat[3:end,3] + 0.12 .* coalesce.(mat[3:end,23])
    elseif circuit == "C2"
        df_enc[!, column_names[3]] = mat[3:end,4] + 0.12 .* coalesce.(mat[3:end,24])
    elseif circuit == "C3"
        df_enc[!, column_names[4]] = mat[3:end,5] + 0.12 .* coalesce.(mat[3:end,25])
    elseif circuit == "C4"
        df_enc[!, column_names[5]] = mat[3:end,6] + 0.12 .* coalesce.(mat[3:end,26])
    end
    
    df_ind_col_3[!, column_names[1]] = mat[3:end,1]
    if circuit == "C1"
        df_ind_col_3[!, column_names[6]] = mat[3:end,15] 
    elseif circuit == "C2"
        df_ind_col_3[!, column_names[7]] = mat[3:end,16]
    elseif circuit == "C3"
        df_ind_col_3[!, column_names[8]] = mat[3:end,17]
    elseif circuit == "C4"
        df_ind_col_3[!, column_names[9]] = mat[3:end,18]
    end
    return df_enc, df_ind_col_3
end
