// La misma multiplicación de matrices de lento.cpp, reescrita.
//
// Reglas: el resultado impreso debe ser idéntico (el checksum tiene que
// coincidir hasta el último decimal) y el formato de salida no cambia, porque
// la verificación lo lee.
//
// TODO: escribir aquí la versión rápida. La estructura del programa se
// conserva; lo que cambia es cómo se recorre la memoria.
#include <chrono>
#include <cstdio>
#include <vector>

using namespace std;
using namespace std::chrono;

const int N = 512;

int main() {
  vector<double> a(N * N), b(N * N), c(N * N, 0.0);
  for (int i = 0; i < N * N; i++) {
    a[i] = (i % 7) * 0.5;
    b[i] = (i % 5) * 0.25;
  }

  auto t0 = high_resolution_clock::now();

  // TODO: la multiplicación va aquí.

  auto t1 = high_resolution_clock::now();

  double suma = 0;
  for (double x : c) suma += x;
  printf("tiempo %ld ms checksum %.3f\n",
         duration_cast<milliseconds>(t1 - t0).count(), suma);
  return 0;
}
