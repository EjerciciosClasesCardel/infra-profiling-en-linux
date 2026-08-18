#include <chrono>
#include <cstdio>
#include <vector>
using namespace std;
using namespace std::chrono;
const int N = 512;
int main() {
  vector<double> a(N*N), b(N*N), c(N*N, 0.0);
  for (int i = 0; i < N*N; i++) { a[i] = (i % 7) * 0.5; b[i] = (i % 5) * 0.25; }
  auto t0 = high_resolution_clock::now();
  for (int i = 0; i < N; i++)
    for (int j = 0; j < N; j++) {
      double s = 0;
      for (int k = 0; k < N; k++) s += a[i*N+k] * b[k*N+j];
      c[i*N+j] = s;
    }
  auto t1 = high_resolution_clock::now();
  double suma = 0; for (double x : c) suma += x;
  printf("tiempo %ld ms checksum %.3f\n", duration_cast<milliseconds>(t1-t0).count(), suma);
}
