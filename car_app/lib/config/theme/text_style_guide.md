# Guía de Estilos de Texto para Car App

## Uso de Fuente Montserrat

Toda la aplicación debe utilizar la fuente Montserrat definida en `theme_config.dart`. No se deben crear instancias directas de `TextStyle` en la interfaz de usuario.

## Cómo Aplicar Estilos de Texto

### Uso Básico
```dart
// ❌ INCORRECTO - No usar TextStyle directamente
Text(
  'Mi texto',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
)

// ✅ CORRECTO - Usar el tema
Text(
  'Mi texto',
  style: Theme.of(context).textTheme.bodyLarge,
)
```

### Personalización Manteniendo la Fuente
Si necesitas personalizar el color u otras propiedades, pero manteniendo la fuente Montserrat:

```dart
Text(
  'Mi texto',
  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: Colors.red,
    // otras propiedades...
  ),
)
```

## Variantes de Texto Disponibles

| Variante | Uso | Tamaño | Peso |
|----------|-----|--------|------|
| `displayLarge` | Títulos principales | 32px | Bold |
| `displayMedium` | Títulos de sección grande | 28px | Bold |
| `displaySmall` | Títulos de sección mediana | 24px | Bold |
| `headlineMedium` | Encabezados | 22px | SemiBold |
| `titleLarge` | Títulos de tarjetas | 20px | SemiBold |
| `titleMedium` | Subtítulos importantes | 18px | SemiBold |
| `titleSmall` | Subtítulos secundarios | 16px | Medium |
| `bodyLarge` | Texto principal | 16px | Regular |
| `bodyMedium` | Texto estándar | 14px | Regular |
| `bodySmall` | Texto pequeño | 12px | Regular |
| `labelLarge` | Etiquetas destacadas | 14px | Medium |

## Recomendaciones

1. **Consistencia**: Utiliza siempre el mismo estilo para elementos similares.
2. **Jerarquía**: Respeta la jerarquía visual usando los estilos según su importancia.
3. **Espaciado**: Asegúrate de que el espaciado entre elementos de texto sea coherente.
4. **Color**: Para cambiar solo el color, usa `copyWith` y mantén los demás aspectos del estilo.
5. **Accesibilidad**: Evita tamaños de texto muy pequeños (menos de 12px) para mejorar la legibilidad.

## Ejemplos de Uso

### Para Encabezados de Sección
```dart
Text(
  'Estadísticas generales',
  style: Theme.of(context).textTheme.titleLarge,
)
```

### Para Texto Normal
```dart
Text(
  'Descripción de la característica',
  style: Theme.of(context).textTheme.bodyMedium,
)
```

### Para Etiquetas Pequeñas
```dart
Text(
  'Último dato actualizado: Hoy',
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
    color: Colors.grey[600],
    fontStyle: FontStyle.italic,
  ),
)
```

## Consideraciones Técnicas

- El uso de Montserrat a través del tema mejora la consistencia de la interfaz.
- La fuente se carga mediante Google Fonts, lo que optimiza el rendimiento.
- Las actualizaciones globales al estilo de texto se realizan en `theme_config.dart`. 