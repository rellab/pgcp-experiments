# save_delaunay_final.jl
#
# yoyogi_park.geojson (単一フィーチャ) を読み込み、
# 1. GeometryBasics: Point2 を明示的に使用
# 2. 'segments' キーワード引数を使用
# して制約付きドロネー分割を実行し、結果を PNG ファイルに出力するスクリプト。
#
# 必要なパッケージ: JSON3.jl, Makie.jl, CairoMakie.jl, DelaunayTriangulation.jl, GeometryBasics.jl

using JSON3
using Makie
using CairoMakie 
using DelaunayTriangulation
using GeometryBasics: Point2  # ★★★ ユーザーご指摘の通り、これを明示的にインポート ★★★

"""
メインの描画処理
"""
function main()
    geojson_filepath = "yoyogi_park.geojson" 

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

    println("Processing the first feature in the file...")
    target_feature = geojson_data.features[1]
    
    if !haskey(target_feature, :geometry) || target_feature.geometry.type != "Polygon"
        println("Error: The first feature is not a valid 'Polygon'.")
        return
    end

    # --- ドロネー分割用のデータを準備 ---
    geometry = target_feature.geometry
    outer_ring_coords = geometry.coordinates[1]
    
    # 1. 座標 (Points) を準備
    # GeometryBasics.jl の Point2 型に変換 (Float64 で精度を保つ)
    # ポリゴンの最後は最初と同じ点なので、[1:end-1] で重複を除去
    points = Point2{Float64}[] # ★ Point2 をプレフィックスなしで使用
    push!(points, [Point2(p[1], p[2]) for p in outer_ring_coords[1:end-1]]...) # ★ Point2 をプレフィックスなしで使用

    if isempty(points)
        println("Error: No valid points found in polygon.")
        return
    end

    # 2. 制約 (Constraints) を準備
    # 'segments' 引数に渡すための、辺のインデックスリスト (1, 2), (2, 3), ..., (N, 1)
    num_points_outer = length(points)
    constraints = NTuple{2, Int}[]
    for i in 1:num_points_outer
        push!(constraints, (i, mod1(i + 1, num_points_outer)))
    end
    
    # 3. 穴 (Holes) を準備 (今回はなし)
    holes = Point2{Float64}[] # ★ Point2 をプレフィックスなしで使用

    # --- 制約付きドロネー分割を実行 ---
    println("Performing constrained Delaunay triangulation...")
    
    # ★★★ 修正点 ★★★
    # 1. DelaunayTriangulation. をプレフィックスとして使用
    # 2. 'constraints=' ではなく 'segments=' をキーワードとして使用
    tri = DelaunayTriangulation.triangulate(points; 
                                            segments=constraints, 
                                            holes=holes)
    
    println("Triangulation complete. Found $(length(tri.triangles)) triangles.")

    # --- Makie で描画 ---
    CairoMakie.activate!()

    fig = Figure(size = (800, 800))
    ax = Axis(fig[1, 1], 
              aspect = DataAspect(),
              title = "Constrained Delaunay Triangulation (Final)",
              xlabel = "Longitude",
              ylabel = "Latitude")

    # 1. ドロネー分割されたメッシュを描画
    # Makie の mesh! 関数は DelaunayTriangulation の tri オブジェクトを直接描画できる
    mesh!(ax, tri, 
          color = :lightblue, 
          strokecolor = :grey,
          strokewidth = 0.5)

    # 2. 元の制約（公園の境界線）を赤で上書き描画
    # Point2{Float64} を Makie の Point2f (Float32) に変換
    shell_points_makie = [Point2f(p[1], p[2]) for p in points]
    poly!(ax, shell_points_makie,
          color = :transparent,
          strokecolor = :red,
          strokewidth = 2)

    # --- ファイルに保存 ---
    output_filename = "yoyogi_park_delaunay.png"
    try
        save(output_filename, fig)
        println("✅ Successfully saved Delaunay triangulation to $output_filename")
    catch e
        println("Error saving file: $e")
    end
end

"""
パッケージ確認
"""
function check_packages()
    try
        @eval using Pkg
        project_deps = Pkg.project().dependencies
        missing_pkgs = []
        
        # ★ GeometryBasics をリストに追加 ★
        for pkg_name in ["JSON3", "Makie", "CairoMakie", "DelaunayTriangulation", "GeometryBasics"]
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