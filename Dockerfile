# CUDD + C++ (cuddObj) 開発用 Dockerfile（動作確認サンプル付き）
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# 必要ツール
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates pkg-config \
    autoconf automake libtool make cmake \
 && rm -rf /var/lib/apt/lists/*

# CUDD を取得してビルド（C++ ラッパを共有ライブラリに含める）
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

# 共有ライブラリを認識させる
RUN ldconfig

# 作業ディレクトリ
WORKDIR /work

# ---- C++ インターフェース(cuddObj)を使った最小サンプル ----
# ここでは main.cpp をその場で作成
RUN cat > /work/main.cpp <<'EOF'
#include <cstddef>      // size_t を先に有効化
#include "cuddObj.hh"   // C++ ラッパ

#include <iostream>

int main() {
    try {
        Cudd mgr;                    // C++ のマネージャ
        BDD x0 = mgr.bddVar();       // 変数 x0
        BDD x1 = mgr.bddVar();       // 変数 x1

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

# ビルド
# cuddObj.hh の配置は環境により /usr/local/include または /usr/local/include/obj にあるため、
# 双方をインクルードパスに入れておくと安全。
RUN g++ -O2 -std=c++17 /work/main.cpp -o /usr/local/bin/cudd_obj_hello \
    -I/usr/local/include -I/usr/local/include/obj \
    -L/usr/local/lib -lcudd

# デフォルトはシェル
CMD ["bash"]