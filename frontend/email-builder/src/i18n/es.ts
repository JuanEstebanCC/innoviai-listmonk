// Traducciones al español para Email Builder
export const translations = {
  // Menú de bloques
  'Add block': 'Agregar bloque',
  'Add': 'Agregar',
  'Text': 'Texto',
  'Button': 'Botón',
  'Image': 'Imagen',
  'Divider': 'Divisor',
  'Spacer': 'Espaciador',
  'Columns': 'Columnas',
  'Container': 'Contenedor',
  'HTML': 'HTML',
  'Avatar': 'Avatar',
  'Heading': 'Encabezado',

  // Acciones de bloques
  'Delete': 'Eliminar',
  'Duplicate': 'Duplicar',
  'Move up': 'Mover arriba',
  'Move down': 'Mover abajo',
  'Copy': 'Copiar',
  'Paste': 'Pegar',

  // Panel de configuración
  'Configuration': 'Configuración',
  'Styles': 'Estilos',
  'Settings': 'Ajustes',

  // Propiedades de estilo
  'Background': 'Fondo',
  'Background color': 'Color de fondo',
  'Background image': 'Imagen de fondo',
  'Padding': 'Espaciado interno',
  'Margin': 'Margen',
  'Border': 'Borde',
  'Border radius': 'Radio del borde',
  'Border color': 'Color del borde',
  'Border width': 'Ancho del borde',
  'Border style': 'Estilo del borde',

  // Propiedades de texto
  'Font': 'Fuente',
  'Font family': 'Familia de fuente',
  'Font size': 'Tamaño de fuente',
  'Font weight': 'Peso de fuente',
  'Font color': 'Color de fuente',
  'Text color': 'Color de texto',
  'Text align': 'Alineación de texto',
  'Line height': 'Altura de línea',
  'Letter spacing': 'Espaciado entre letras',
  'Text decoration': 'Decoración de texto',

  // Alineación
  'Left': 'Izquierda',
  'Center': 'Centro',
  'Right': 'Derecha',
  'Justify': 'Justificado',

  // Tamaños
  'Width': 'Ancho',
  'Height': 'Alto',
  'Max width': 'Ancho máximo',
  'Max height': 'Alto máximo',
  'Min width': 'Ancho mínimo',
  'Min height': 'Alto mínimo',

  // Botón
  'Button text': 'Texto del botón',
  'Button URL': 'URL del botón',
  'Button color': 'Color del botón',
  'Button background': 'Fondo del botón',
  'Link': 'Enlace',
  'URL': 'URL',
  'Target': 'Destino',

  // Imagen
  'Image URL': 'URL de imagen',
  'Alt text': 'Texto alternativo',
  'Image width': 'Ancho de imagen',
  'Image height': 'Alto de imagen',

  // Email Layout
  'Email layout': 'Diseño de email',
  'Email settings': 'Configuración de email',
  'Canvas': 'Lienzo',
  'Canvas color': 'Color del lienzo',
  'Content width': 'Ancho del contenido',
  'Content background': 'Fondo del contenido',

  // Columnas
  'Columns count': 'Número de columnas',
  'Column': 'Columna',
  'Column width': 'Ancho de columna',
  'Gap': 'Espacio',

  // HTML
  'HTML content': 'Contenido HTML',
  'Raw HTML': 'HTML sin procesar',
  'Custom code': 'Código personalizado',

  // Panel de plantilla
  'Template': 'Plantilla',
  'HTML': 'HTML',
  'JSON': 'JSON',
  'Download': 'Descargar',
  'Import': 'Importar',
  'Export': 'Exportar',
  'Download HTML': 'Descargar HTML',
  'Download JSON': 'Descargar JSON',
  'Import JSON': 'Importar JSON',
  'Copy HTML': 'Copiar HTML',
  'Copy JSON': 'Copiar JSON',
  'Share': 'Compartir',

  // Mensajes
  'Are you sure?': '¿Estás seguro?',
  'This action cannot be undone': 'Esta acción no se puede deshacer',
  'Cancel': 'Cancelar',
  'Confirm': 'Confirmar',
  'Save': 'Guardar',
  'Close': 'Cerrar',
  'Apply': 'Aplicar',
  'Reset': 'Restablecer',

  // Validación
  'Required': 'Requerido',
  'Invalid URL': 'URL inválida',
  'Invalid email': 'Email inválido',
  'Invalid color': 'Color inválido',

  // Pesos de fuente
  'Normal': 'Normal',
  'Bold': 'Negrita',
  'Light': 'Ligera',
  'Thin': 'Delgada',
  'Extra Light': 'Extra Ligera',
  'Medium': 'Media',
  'Semi Bold': 'Semi Negrita',
  'Extra Bold': 'Extra Negrita',
  'Black': 'Negro',

  // Unidades
  'px': 'px',
  '%': '%',
  'auto': 'automático',
  'none': 'ninguno',

  // Divisor
  'Divider': 'Divisor',
  'Line color': 'Color de línea',
  'Line width': 'Ancho de línea',
  'Line style': 'Estilo de línea',

  // Espaciador
  'Spacer': 'Espaciador',
  'Spacer height': 'Altura del espaciador',

  // Otros
  'Preview': 'Vista previa',
  'Edit': 'Editar',
  'Insert': 'Insertar',
  'Above': 'Arriba',
  'Below': 'Abajo',
  'Before': 'Antes',
  'After': 'Después',
};

export type TranslationKey = keyof typeof translations;

export function t(key: TranslationKey): string {
  return translations[key] || key;
}

