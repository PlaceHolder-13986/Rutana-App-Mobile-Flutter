# language: es
Característica: Vehículos y equipos de Qoritech
  Las historias HU-V, HU-E y HU-R son alias; reemplazarlos por los IDs del sprint.

  @HU-V @integracion-local
  Escenario: Rechazar placas equivalentes
    Dado que existe un vehículo habilitado
    Cuando registro la misma placa con espacios y minúsculas
    Entonces se rechaza el duplicado sin cambiar la flota

  @HU-R @integracion-local
  Escenario: Detectar conflicto de vehículo
    Dado que existe un viaje publicado
    Cuando publico otro viaje con el mismo vehículo
    Entonces el error identifica el vehículo y el viaje original

  @HU-R @integracion-local
  Escenario: Detectar conflicto de conductor
    Dado que existe un viaje publicado
    Cuando publico otro viaje con el mismo conductor y otro vehículo
    Entonces el error identifica el conductor y el viaje original

  @HU-V @integracion-local
  Escenario: Proteger estado del vehículo asignado
    Dado que existe un viaje publicado
    Cuando deshabilito su vehículo
    Entonces el error identifica el viaje que debe atender el coordinador

  @HU-R @integracion-local
  Escenario: Rechazar vehículo en mantenimiento
    Dado que existe un vehículo en mantenimiento
    Cuando publico un viaje con ese vehículo
    Entonces la publicación se rechaza y el viaje sigue en borrador

  @HU-V @aceptacion-widget
  Escenario: Registrar editar y rechazar duplicado desde el formulario
    Dado que abro Vehículos y equipos como administrador
    Cuando registro un vehículo desde el formulario
    Entonces el vehículo aparece en el listado
    Cuando edito su capacidad desde el detalle
    Entonces la capacidad actualizada aparece en el listado
    Cuando registro una placa equivalente desde el formulario
    Entonces el formulario muestra el rechazo por placa duplicada

  @HU-E @aceptacion-widget
  Escenario: Crear tripulación desde el formulario
    Dado que abro Vehículos y equipos como administrador
    Cuando creo un equipo con conductor y ayudante
    Entonces el equipo aparece con su conductor y ayudante
