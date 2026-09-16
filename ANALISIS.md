# Análisis

Nombre y código:

## El programa visto desde afuera

Con `evidencia/ps.txt`: cuántos hilos aparecen, qué `%CPU` reporta `ps` para
cada uno y qué reporta `top`, y por qué los dos números no coinciden para el
mismo hilo. En qué procesador (`PSR`) corría cada hilo en ese instante.

## Lo que mostró el perfil

(Cuál función concentra el tiempo, con el número que lo respalda. Si `perf stat`
reportó fallos de caché, cuántos y sobre cuántos accesos.)

## Los fallos de caché, versión por versión

| Versión | Accesos a datos (`D refs`) | Fallos en D1 | Tasa D1 |
|---|---:|---:|---:|
| lento |  |  |  |
| rápido |  |  |  |

Por qué la tasa cambia tanto cuando la cantidad de multiplicaciones es la
misma:

## Qué se cambió y por qué

(La modificación concreta y la razón, en términos de cómo se recorre la
memoria.)

## Resultado

| Versión | Tiempo | Checksum |
|---|---:|---|
| lento |  |  |
| rápido |  |  |

Aceleración obtenida:
