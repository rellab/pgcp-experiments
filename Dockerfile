FROM julia:1.10
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    pkg-config \
    file \
    git \
    automake \
    autoconf \
    libtool \
    m4 \
    perl \
    && rm -rf /var/lib/apt/lists/*

RUN julia --color=yes -e 'using Pkg; \
    Pkg.add(url="https://github.com/JuliaReliab/MiniCUDD.jl.git"); \
    Pkg.build("MiniCUDD"); \
    Pkg.precompile(); \
    Pkg.test("MiniCUDD")'

RUN julia --color=yes -e 'using Pkg; \
    Pkg.add(["JSON","JSON3","ProgressMeter","DataStructures", \
             "Plots","GeometryBasics","VoronoiCells","Makie","HTTP","CairoMakie","DelaunayTriangulation"]); \
    Pkg.precompile()'

WORKDIR /work

CMD ["julia"]
