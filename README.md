# Codex PDF417 Creator

**Anthony Marrero · aeternumintelligencecorp**

Código fuente de la aplicación macOS instalada como **PDF417 Creator 2.7**, compilación28. También utiliza el nombre CodeStudio en algunas herramientas de su interfaz. El título del repositorio no implica afiliación con OpenAI.

Crea códigos PDF417 y otros formatos compatibles, permite ajustar su presentación y exportarlos. Incluye lectura de códigos desde imágenes, proyectos guardados, series, herramientas de inventario y transferencia local al teléfono.

## Requisitos y compilación

macOS13 o posterior y Xcode o sus herramientas de desarrollo. El código usa frameworks del sistema: AppKit, Core Image, Vision, Network y Uniform Type Identifiers; no requiere paquetes externos.

```sh
zsh build.sh
```

La compilación crea un ZIP en `dist/` con ejecutables Apple Silicon e Intel. La firma es local; no está notarizada por Apple y macOS puede bloquear copias descargadas. La validación de esta publicación comprueba compilación para ambas arquitecturas, no funcionamiento exhaustivo de cada opción ni compatibilidad con todos los lectores.

## Funciones y límites

- Generación de PDF417, QR, Aztec, Code128 y otros formatos implementados.
- Ajustes de colores, escala, márgenes y opciones según el formato.
- Exportación de imágenes, PDF y SVG. El SVG contiene una imagen PNG incrustada; no es una reconstrucción vectorial de los módulos.
- Lectura desde imágenes mediante Apple Vision.
- Series y lotes básicos desde CSV; proyectos con extensión `.codestudio`.
- Inventario y estadísticas guardados localmente.
- Transferencia al teléfono mediante un servidor HTTP temporal en la red local con enlace aleatorio; cancela la transferencia cuando termines.

El catálogo incluye formatos de referencia que **no tienen generador implementado**. Su presencia no garantiza que puedan crearse. La lectura depende del contenido, contraste, tamaño y dispositivo; prueba el código con el lector de destino antes de usarlo.

## Privacidad

No se incluyen borradores, historial, favoritos, inventarios, imágenes, datos de usuario ni credenciales. Las preferencias y los proyectos de tu Mac no forman parte del código. No uses información sensible en un enlace de transferencia por una red no confiable.

## Guía y contribuciones

[Guía de inicio](GUIA.md) · [Ficha del programa](FICHA.md) · [Errores y sugerencias](https://github.com/jessiel212/Codex-PDF417-Creator/issues/new/choose)

Las pruebas y reportes públicos deben utilizar contenidos sintéticos, sin información personal ni contraseñas Wi-Fi reales.

Código propio bajo [licencia MIT](LICENSE). Los frameworks y símbolos del sistema pertenecen a sus respectivos titulares y no se redistribuyen como código del proyecto.
