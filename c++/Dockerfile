# CUDD + C++ (cuddObj) development Dockerfile (with sample for verification)
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates pkg-config \
    autoconf automake libtool make cmake \
 && rm -rf /var/lib/apt/lists/*

# Get and build CUDD (include C++ wrapper in shared library)
WORKDIR /opt
RUN git clone --depth 1 https://github.com/ivmai/cudd.git
WORKDIR /opt/cudd
RUN autoreconf -fiv \
 && ./configure --enable-silent-rules \
                --enable-shared \
                --enable-static \
                --enable-obj \
 && make -j"$(nproc)" \
 && make install

# Make shared libraries available
RUN ldconfig

# Working directory
WORKDIR /work

# ---- Minimal sample using C++ interface (cuddObj) ----
# Here, create main.cpp on the fly

RUN cat > /work/main.cpp <<'EOF'
#include <cstddef>      // enable size_t first
#include "cuddObj.hh"   // C++ wrapper

#include <iostream>

int main() {
    try {

    Cudd mgr;                    // C++ manager
    BDD x0 = mgr.bddVar();       // variable x0
    BDD x1 = mgr.bddVar();       // variable x1

    BDD f = x0 & x1;             // f = x0 AND x1
    BDD g = x0 | x1;             // g = x0 OR x1

        std::cout << "f node count = " << f.nodeCount() << "\n";
        std::cout << "g node count = " << g.nodeCount() << "\n";
        std::cout << "equal? " << (f == g) << "\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << "\n";
        return 1;
    }
}
EOF

# Build
# Depending on the environment, cuddObj.hh may be in /usr/local/include or /usr/local/include/obj,
# so it is safer to include both in the include path.
RUN g++ -O2 -std=c++17 /work/main.cpp -o /usr/local/bin/cudd_obj_hello \
    -I/usr/local/include -I/usr/local/include/obj \
    -L/usr/local/lib -lcudd

# Default is shell
CMD ["bash"]