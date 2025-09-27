// main.cpp — CUDD C++ ラッパ (cuddObj) 版
// g++ -O2 -std=c++17 main.cpp -o app -I/usr/local/include -I/usr/local/include/obj -L/usr/local/lib -lcudd

#include <cstddef>
#include "cuddObj.hh"
#include <iostream>
#include <vector>
#include <string>
#include <deque>
#include <unordered_map>
#include <algorithm>
#include <cmath>
#include <chrono>
#include <random>
#include <optional>
#include <iterator>   // ★ 追加: back_inserter
#include <iomanip>    // ★ 追加: setprecision
#include <fstream>    // ★ 追加: ifstream 用

// ===================== 幾何ユーティリティ =====================
struct Point { double x, y; };

struct Circle {
    std::string name;
    Point center;
    double radius;
};

struct Rectangle4 {
    std::vector<Point> v; // 左下, 左上, 右上, 右下
    Rectangle4() = default;
    explicit Rectangle4(std::vector<Point> vv) : v(std::move(vv)) {}
};

inline bool isinside(const Circle& c, const Point& p) {
    double dx = p.x - c.center.x, dy = p.y - c.center.y;
    return dx*dx + dy*dy <= c.radius * c.radius + 1e-15;
}

static inline double dist(const Point& a, const Point& b) {  // ★ 追加
    double dx=a.x-b.x, dy=a.y-b.y; return std::sqrt(dx*dx+dy*dy);
}

// 長方形を gridsize×gridsize に等分
static std::vector<Rectangle4> createarea(const Rectangle4& rect, int gridsize) {
    std::vector<Rectangle4> out;
    out.reserve(gridsize * gridsize);

    const double x0 = rect.v[0].x, y0 = rect.v[0].y; // 左下
    const double x1 = rect.v[2].x, y1 = rect.v[2].y; // 右上

    for (int i = 0; i < gridsize; ++i) {
        for (int j = 0; j < gridsize; ++j) {
            double xa = x0 + (x1 - x0) * double(i) / gridsize;
            double xb = x0 + (x1 - x0) * double(i + 1) / gridsize;
            double ya = y0 + (y1 - y0) * double(j) / gridsize;
            double yb = y0 + (y1 - y0) * double(j + 1) / gridsize;
            out.emplace_back(std::vector<Point>{{xa, ya}, {xa, yb}, {xb, yb}, {xb, ya}});
        }
    }
    return out;
}

// ===================== BDD ユーティリティ =====================
static BDD bdd_and(Cudd& M, const std::vector<BDD>& vs) {
    if (vs.empty()) return M.bddOne();
    BDD acc = M.bddOne();
    for (const auto& b : vs) acc &= b;
    return acc;
}
static BDD bdd_or(Cudd& M, const std::vector<BDD>& vs) {
    if (vs.empty()) return M.bddZero();
    BDD acc = M.bddZero();
    for (const auto& b : vs) acc |= b;
    return acc;
}

template<class T>
static std::vector<T> set_intersection_vec(std::vector<T> a, std::vector<T> b) {
    std::sort(a.begin(), a.end());
    std::sort(b.begin(), b.end());
    std::vector<T> out;
    std::set_intersection(a.begin(), a.end(), b.begin(), b.end(), std::back_inserter(out));
    return out;
}

// ===================== bddsolver =====================
struct SolverResult {
    BDD varphi1, varphi2;
    bool conv;
    int  level;
    std::vector<std::pair<int,int>> areasByLevel;
};

static SolverResult bddsolver(
    Cudd& M,
    const std::unordered_map<std::string,int>& vars,
    const std::vector<Circle>& circles,
    const Rectangle4& root,
    int gridsize = 4,
    int maxlevel = 10
){
    BDD varphi1 = M.bddOne();
    BDD varphi2 = M.bddOne();

    std::deque<std::pair<Rectangle4,int>> q;
    q.emplace_back(root, 1);

    int total = 1, processed = 0;
    std::unordered_map<int,int> totalarea;

    auto t0 = std::chrono::steady_clock::now();
    int level = 1;

    while (!q.empty()) {
        auto [rect, curLevel] = q.front(); q.pop_front();
        level = curLevel;
        processed++;

        auto areas = createarea(rect, gridsize);
        for (const auto& r : areas) {
            std::vector<std::vector<int>> idxsPerVertex(4);
            for (int k = 0; k < 4; ++k) {
                const Point& p = r.v[k];
                for (const auto& c : circles) {
                    if (isinside(c, p)) {
                        if (auto it = vars.find(c.name); it != vars.end()) {
                            idxsPerVertex[k].push_back(it->second);
                        }
                    }
                }
            }
            std::vector<int> vars2 = idxsPerVertex[0];
            for (int k = 1; k < 4; ++k) vars2 = set_intersection_vec(vars2, idxsPerVertex[k]);

            std::vector<BDD> ors; ors.reserve(4);
            for (auto& vv : idxsPerVertex) {
                std::vector<BDD> tmp; tmp.reserve(vv.size());
                for (int id : vv) tmp.push_back(M.bddVar(id));
                ors.push_back(bdd_or(M, tmp));
            }
            BDD varphi1new = bdd_and(M, ors);

            std::vector<BDD> tmp2; tmp2.reserve(vars2.size());
            for (int id : vars2) tmp2.push_back(M.bddVar(id));
            BDD varphi2new = bdd_or(M, tmp2);

            BDD varphi1dash = varphi1 & varphi1new;
            BDD varphi2dash = varphi2 & varphi2new;

            bool same_new  = (varphi1new.getNode()  == varphi2new.getNode());
            bool same_dash = (varphi1dash.getNode() == varphi2dash.getNode());

            if (same_new || same_dash || curLevel == maxlevel) {
                varphi1 = varphi1dash;
                varphi2 = varphi2dash;
                totalarea[curLevel] += 1;
            } else {
                q.emplace_back(r, curLevel + 1);
                total += 1;
            }
        }

        double pct = 100.0 * processed / std::max(1, total);
        auto sec = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
        double eta = processed ? sec * (total - processed) / processed : 0.0;

        std::cout << "\rProgress (level " << level << "): "
                  << processed << " / " << total << " ("
                  << std::round(pct*10)/10 << "%) ETA: "
                  << std::round(eta*100)/100 << "s" << std::flush;
    }
    std::cout << "...Done\n";

    std::vector<std::pair<int,int>> areasByLevel;
    areasByLevel.reserve(totalarea.size());
    for (auto& kv : totalarea) areasByLevel.emplace_back(kv.first, kv.second);
    std::sort(areasByLevel.begin(), areasByLevel.end());

    return { varphi1, varphi2, varphi1.getNode() == varphi2.getNode(), level, areasByLevel };
}

// ===================== CSV 読み込み =====================
// ヘッダ: name,x,y,radius
static std::vector<Circle> readCirclesFromCSV(const std::string& filename) {
    std::vector<Circle> circles;
    std::ifstream file(filename);
    if (!file.is_open()) {
        throw std::runtime_error("Could not open CSV: " + filename);
    }

    std::string line;
    // 1行目（ヘッダ）を読み飛ばす
    if (!std::getline(file, line)) {
        throw std::runtime_error("CSV is empty: " + filename);
    }

    while (std::getline(file, line)) {
        if (line.empty()) continue;
        std::stringstream ss(line);

        std::string name, xs, ys, rs;
        if (!std::getline(ss, name, ',')) continue;
        if (!std::getline(ss, xs, ',')) continue;
        if (!std::getline(ss, ys, ',')) continue;
        if (!std::getline(ss, rs, ',')) continue;

        Circle c;
        c.name = name;
        c.center.x = std::stod(xs);
        c.center.y = std::stod(ys);
        c.radius   = std::stod(rs);

        circles.push_back(c);
    }
    return circles;
}

static double prob_rec(DdManager* mgr, DdNode* f,
                       const std::unordered_map<int,double>& pb,
                       std::unordered_map<DdNode*, double>& memo)
{
    // 真理値端点
    if (f == Cudd_ReadOne(mgr))  return 1.0;
    if (f == Cudd_ReadLogicZero(mgr)) return 0.0;

    // 正規ノード（補完ビットを落とす）
    DdNode* reg = Cudd_Regular(f);
    const bool isCompl = Cudd_IsComplement(f);

    // メモ化（正規ノードに対してキャッシュ）
    auto it = memo.find(reg);
    if (it != memo.end()) {
        // ここで補完ビットを反映
        return isCompl ? (1.0 - it->second) : it->second;
    }

    // 変数インデックス
    const int var = Cudd_NodeReadIndex(reg);
    auto pit = pb.find(var);
    if (pit == pb.end()) {
        throw std::runtime_error("prob: missing probability for var index " + std::to_string(var));
    }
    const double p = pit->second;

    // 子（then/else）
    DdNode* T = Cudd_T(reg);
    DdNode* E = Cudd_E(reg);

    // f が補完なら、子も補完して評価（Not を付ける）
    if (isCompl) {
        T = Cudd_Not(T);
        E = Cudd_Not(E);
    }

    // 再帰（参照カウントは不要：読み取りのみ）
    const double pt = prob_rec(mgr, T, pb, memo);
    const double pe = prob_rec(mgr, E, pb, memo);

    // 現ノードの確率
    const double pf = p * pt + (1.0 - p) * pe;

    // 正規ノードでキャッシュ（補完は呼び出し側で 1 - 値 をとるので reg に対してのみ保存）
    memo.emplace(reg, pf);
    return pf;
}

// 外部インターフェイス（cuddObj の BDD でも呼べる）
double prob(Cudd& M, const BDD& F, const std::unordered_map<int,double>& pb)
{
    std::unordered_map<DdNode*, double> memo;
    memo.reserve(F.nodeCount() * 2);
    return prob_rec(M.getManager(), F.getNode(), pb, memo);
}

// ===================== main =====================
int main(int argc, char** argv) {
    if (argc < 4){
        std::cerr << "Usage: " << argv[0]
                  << " <circles.csv> <gridsize> <maxlevel> [reliability]\n";
        return 1;
    }

    const std::string csvpath = argv[1];
    const int    gridsize  = std::stoi(argv[2]);
    const int    maxlevel  = std::stoi(argv[3]);
    const double reliability = (argc >= 5) ? std::stod(argv[4]) : 0.9;

    std::cout << std::fixed << std::setprecision(6);
    std::cout << "CSV: " << csvpath << "\n";
    std::cout << "Reliability(all): " << reliability << "\n";
    std::cout << "Gridsize: " << gridsize << "\n";
    std::cout << "Maxlevel: " << maxlevel << "\n";

    // === CSV から読み込み ===
    std::vector<Circle> circles = readCirclesFromCSV(csvpath);

    // === 原点からの距離でソート ===
    std::sort(circles.begin(), circles.end(),
            [](const Circle& a, const Circle& b){
                return dist(a.center, {0,0}) < dist(b.center, {0,0});
            });


    // === vars / pb を構築（p は全て同一） ===
    std::unordered_map<std::string,int> vars;
    vars.reserve(circles.size());
    std::unordered_map<int,double> pb;
    pb.reserve(circles.size());
    for (size_t i=0;i<circles.size();++i){
        vars[circles[i].name] = static_cast<int>(i);
        pb[static_cast<int>(i)] = reliability;
    }

    // std::vector<Circle> circles;
    // circles.reserve(pts.size());
    // for (size_t i=0;i<pts.size();++i){
    //     double r = radius_choices[pick(rng)];
    //     circles.push_back(Circle{ std::to_string(i+1), pts[i], r });
    // }

    // std::sort(circles.begin(), circles.end(),
    //           [](const Circle& a, const Circle& b){
    //               return dist(a.center, {0,0}) < dist(b.center, {0,0});
    //           });

    // std::unordered_map<std::string,int> vars;
    // vars.reserve(circles.size());
    // std::unordered_map<int,double> pb;
    // pb.reserve(circles.size());
    // for (size_t i=0;i<circles.size();++i){
    //     vars[circles[i].name] = static_cast<int>(i);
    //     pb[static_cast<int>(i)] = reliability;
    // }

    std::cout << "Number of circles: " << circles.size() << "\n";
    // for (size_t i=0;i<circles.size();++i){
    //     const auto& c = circles[i];
    //     std::cout << "  Circle " << c.name
    //               << ": center=(" << c.center.x << "," << c.center.y << "), radius=" << c.radius << "\n";
    // }

    Cudd M;

    // ★ targetarea を定義（例: [0,0]~[1,1] の正方形）
    Rectangle4 targetarea({{0,0}, {0,1}, {1,1}, {1,0}});

    auto t0 = std::chrono::steady_clock::now();
    auto res = bddsolver(M, vars, circles, targetarea, gridsize, maxlevel);
    auto t1 = std::chrono::steady_clock::now();
    double t_solve = std::chrono::duration<double>(t1 - t0).count();

    std::cout << "Convergence: " << (res.conv ? "true" : "false") << "\n";
    std::cout << "Level: " << res.level << "\n";
    std::cout << "Area: [";
    for (size_t i=0;i<res.areasByLevel.size();++i){
        auto [lv, cnt] = res.areasByLevel[i];
        std::cout << "(" << lv << "," << cnt << ")";
        if (i+1<res.areasByLevel.size()) std::cout << ", ";
    }
    std::cout << "]\n";
    std::cout << "Circles: " << circles.size() << "\n";
    std::cout << "Nodes: " << res.varphi1.nodeCount() << "\n";
    std::cout << "SolveTime(sec): " << t_solve << "\n";

    auto t2 = std::chrono::steady_clock::now();
    double lb = prob(M, res.varphi2, pb);
    auto t3 = std::chrono::steady_clock::now();
    double ub = prob(M, res.varphi1, pb);
    auto t4 = std::chrono::steady_clock::now();

    std::cout << std::fixed << std::setprecision(15);
    std::cout << "Reliability: [" << lb << ", " << ub << "]\n";
    std::cout << std::fixed << std::setprecision(8);
    std::cout << "ProbTime(varphi2): "
              << std::chrono::duration<double>(t3 - t2).count() << " sec, "
              << "ProbTime(varphi1): "
              << std::chrono::duration<double>(t4 - t3).count() << " sec\n";

    return 0;
}