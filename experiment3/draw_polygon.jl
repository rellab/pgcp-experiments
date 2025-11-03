# save_single_polygon_png.jl
#
# 1つのフィーチャを含む GeoJSON を読み込み、
# Makie と CairoMakie を使って PNG ファイルに出力するスクリプト。
# (座標フィルターを削除し、簡略化)
#
# 必要なパッケージ: JSON3.jl, Makie.jl, CairoMakie.jl

using JSON3
using Makie
using CairoMakie 

"""
メインの描画処理
"""
function main()
    geojson_filepath = "yoyogi_park.geojson" # このファイルに提示されたデータが保存されていると仮定

    if !isfile(geojson_filepath)
        println("Error: GeoJSON file not found at '$geojson_filepath'")
        return
    end

    println("Loading polygon data from '$geojson_filepath'...")
    local geojson_data
    try
        geojson_data = JSON3.read(read(geojson_filepath, String))
    catch e
        println("Error reading or parsing JSON file: $e")
        return
    end
    
    if !haskey(geojson_data, :features) || isempty(geojson_data.features)
        println("Error: GeoJSON file contains no features.")
        return
    end

    # --- ★ 修正点 ★ ---
    # 座標フィルターを削除し、常に「最初のフィーチャ」を描画対象とする
    println("Processing the first feature in the file...")
    target_feature = geojson_data.features[1] # 1番目のフィーチャを取得
    
    if !haskey(target_feature, :geometry) || target_feature.geometry.type != "Polygon"
        println("Error: The first feature is not a valid 'Polygon'.")
        return
    end
    # --- 修正ここまで ---

    # --- 描画用の座標データを準備 ---
    geometry = target_feature.geometry
    
    # 外部リング (Shell)
    # geometry.coordinates[1] を使う (Julia の 1-index)
    outer_ring_coords = geometry.coordinates[1]
    shell_points = [Point2f(p[1], p[2]) for p in outer_ring_coords]
    
    # 内部リング (Holes)
    hole_point_lists = []
    
    # ご提示のデータは length(geometry.coordinates) が 1 なので、
    # この if ブロックは実行されない (正常な動作)
    if length(geometry.coordinates) > 1
        println("Found holes (inner rings). Processing them...")
        for i in 2:length(geometry.coordinates)
            inner_ring_coords = geometry.coordinates[i]
            push!(hole_point_lists, [Point2f(p[1], p[2]) for p in inner_ring_coords])
        end
    end

    # --- Makie で描画 ---
    CairoMakie.activate!()

    fig = Figure(size = (800, 800))
    ax = Axis(fig[1, 1], 
              aspect = DataAspect(),
              title = "Yoyogi Park Polygon (Single Feature)",
              xlabel = "Longitude",
              ylabel = "Latitude")

    # 1. 外部ポリゴンを描画
    poly!(ax, shell_points, 
          color = :lightblue, 
          strokecolor = :black, 
          strokewidth = 2)

    # 2. 穴を描画
    # ご提示のデータの場合、hole_point_lists は空なので、
    # この if ブロックは実行されない (正常な動作)
    if !isempty(hole_point_lists)
        for hole_shell in hole_point_lists
            poly!(ax, hole_shell, 
                  color = :white,
                  strokecolor = :grey,
                  strokewidth = 1)
        end
    end

    # --- ファイルに保存 ---
    output_filename = "yoyogi_park_polygon.png"
    try
        save(output_filename, fig)
        println("✅ Successfully saved plot to $output_filename")
    catch e
        println("Error saving file: $e")
    end
end

"""
パッケージ確認（変更なし）
"""
function check_packages()
    try
        @eval using Pkg
        project_deps = Pkg.project().dependencies
        missing_pkgs = []
        
        for pkg_name in ["JSON3", "Makie", "CairoMakie"]
             if !haskey(project_deps, pkg_name)
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

# スクリプトとして直接実行された場合のみ main 処理を実行
if abspath(PROGRAM_FILE) == @__FILE__
    if check_packages()
        main()
    end
end