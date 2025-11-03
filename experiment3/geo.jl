# geo.jl (修正版)
#
# OpenStreetMap (Overpass API) から代々木公園のポリゴンデータを取得し、
# GeoJSON ファイルとして保存するスクリプト。
#
# 必要なパッケージ: HTTP.jl, JSON3.jl
# ※ GeoJSON.jl は書き込みバグの疑いがあるため使用を停止

using HTTP
using JSON3
# using GeoJSON # <- 使用停止

"""
Overpass API にクエリを送信し、代々木公園のポリゴンを取得して GeoJSON ファイルに保存します。
"""
function get_yoyogi_park_polygon()
    
    # Overpass API のエンドポイント (メインサーバーに戻します)
    # (混雑時は 'https://overpass.openstreetmap.fr/api/interpreter' などに変更)
    overpass_url = "https://overpass-api.de/api/interpreter"

    # Overpass QL クエリ
    # 東京周辺の Bounding Box (bbox) (南, 西, 北, 東) を追加して絞り込み
    # (35.6, 139.6, 35.8, 139.8)
    query = """
    [out:json][timeout:25];
    (
      relation["leisure"="park"]["name"="代々木公園"](35.6, 139.6, 35.8, 139.8);
      way["leisure"="park"]["name"="代々木公園"](35.6, 139.6, 35.8, 139.8);
      relation["leisure"="park"]["name:en"="Yoyogi Park"](35.6, 139.6, 35.8, 139.8);
      way["leisure"="park"]["name:en"="Yoyogi Park"](35.6, 139.6, 35.8, 139.8);
    );
    out geom;
    """

    println("Querying Overpass API for Yoyogi Park polygon...")

    local json_data
    try
        response = HTTP.post(overpass_url, [], query)
        
        if response.status != 200
            println("Error: Overpass API request failed.")
            println("Status: $(response.status)")
            println("Body: $(String(response.body))")
            return
        end
        
        json_data = JSON3.read(response.body)
        
    catch e
        println("Error during HTTP request or JSON parsing: $e")
        return
    end

    if !haskey(json_data, :elements) || isempty(json_data.elements)
        println("Error: Could not find Yoyogi Park polygon (no elements returned).")
        return
    end

    println("Data received. Processing geometries...")

    features = []
    
    for element in json_data.elements
        if element.type == "node"
            continue
        end

        geom_type = ""
        coordinates = []
        
        try
            if element.type == "way"
                if !haskey(element, :geometry) continue end
                
                geom_type = "Polygon"
                coords = [[pt.lon, pt.lat] for pt in element.geometry]
                if isempty(coords) continue end
                if coords[1] != coords[end]
                    push!(coords, coords[1])
                end
                coordinates = [coords]

            elseif element.type == "relation"
                if !haskey(element, :members) continue end
                
                outers_geom = [] 
                inners_geom = [] 
                
                for member in element.members
                    if member.type == "way" && haskey(member, :geometry)
                        
                        coords = [[pt.lon, pt.lat] for pt in member.geometry]
                        if isempty(coords) continue end
                        if coords[1] != coords[end]
                            push!(coords, coords[1])
                        end
                        
                        if member.role == "outer"
                            push!(outers_geom, coords)
                        elseif member.role == "inner"
                            push!(inners_geom, coords)
                        end
                    end
                end

                if isempty(outers_geom)
                    continue
                elseif length(outers_geom) == 1
                    geom_type = "Polygon"
                    coordinates = [outers_geom[1]]
                    append!(coordinates, inners_geom) 
                else
                    geom_type = "MultiPolygon"
                    coordinates = [ [outer] for outer in outers_geom ]
                end
            
            else
                continue
            end
            
            push!(features, Dict(
                :type => "Feature",
                :geometry => Dict(
                    :type => geom_type,
                    :coordinates => coordinates
                ),
                :properties => haskey(element, :tags) ? element.tags : Dict()
            ))

        catch e
             println("Warning: Failed to process element $(element.id). Error: $e")
        end
        
    end # end for elements

    if isempty(features)
        println("No valid geometry features were processed.")
        return
    end

    feature_collection = Dict(
        :type => "FeatureCollection",
        :features => features
    )
    
    # 7. GeoJSONとして保存 (JSON3.write を使用)
    filepath = "yoyogi_park.geojson"
    try
        # println("DEBUG: Writing data: ", feature_collection) # デバッグ行はコメントアウト
        
        open(filepath, "w") do f
            # --------------------------------------------------
            # ★ 修正点 ★
            # GeoJSON.write(f, feature_collection)
            # ↓
            JSON3.write(f, feature_collection)
            # --------------------------------------------------
        end
        println("✅ Successfully saved polygon(s) to $filepath")
        
    catch e
        println("Error writing JSON file: $e")
    end
end

function check_packages()
    try
        @eval using Pkg
        installed = Pkg.installed()
        missing_pkgs = []
        
        # 'GeoJSON' をリストから削除
        for pkg_name in ["HTTP", "JSON3"] 
             if !haskey(installed, pkg_name)
                push!(missing_pkgs, pkg_name)
            end
        end
        
        if !isempty(missing_pkgs)
            println("🛑 必要なパッケージが不足しています: $(join(missing_pkgs, ", "))")
            println("以下のコマンドをJulia REPLで実行してインストールしてください:")
            println("using Pkg; Pkg.add.([" * join("\"$p\"" for p in missing_pkgs) * "])")
            return false
        end
        return true
        
    catch e
        println("Warning: Could not verify packages. $e")
        return true
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    if check_packages()
        get_yoyogi_park_polygon()
    end
end