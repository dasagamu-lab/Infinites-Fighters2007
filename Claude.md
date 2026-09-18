# Contexto y Reglas del Proyecto

## 🎮 Descripción del Juego
- **Tipo:** Juego de peleas 2D en Godot Engine.
- **Lenguaje:** GDScript.
- **Sistemas principales:** 
  - Selección de personajes (incluyendo a Lum y Sierv).
  - Máquina de Estados Finitos (FSM) para las acciones del personaje (Idle, Attack, Hitstun, Jump, etc.).
  - Sistema de hitbox / hurtbox para detección de golpes.
  - Gestión de rondas, interfaz y menú de pausa.
  Todo esta en una base muy temprana se espera que se pula todo muy bien para tener un resultado satisfactorio[

## ⚠️ Reglas estrictas para la IA (No romper el proyecto)
1. **No modificar sin explicar:** Antes de hacer un cambio en la lógica, explica brevemente qué causaba el problema y qué vas a cambiar.
2. **Respetar la arquitectura:** Conserva las funciones, nodos y señales de los scripts de selección de personajes y control de rondas existentes.
3. **Control de estados y animaciones:** Ten especial cuidado con la sincronización de animaciones, hitstun y transiciones de estados para que el combate se sienta fluido.
4. **Respetar nombres y tipos:** No cambies el nombre de las señales (signals), variables exportadas (`@export`) ni tipos de datos sin consulta previa.
5. **Formato limpio:** Mantén la sangría correcta en GDScript (uso estricto de tabs/espacios según el proyecto) para evitar errores de sintaxis.

## 🛠️ Comandos útiles / Flujo
- Al proponer correcciones de bugs, ofrece primero un diagnóstico y espera confirmación antes de modificar varios archivos a la vez.
