# ビルド
docker build -t cudd-cpp:obj .

# 実行（動作確認）
docker run --rm cudd-cpp:obj /usr/local/bin/cudd_obj_hello
# => f/g の node count と equal?=0/1 が表示されればOK
