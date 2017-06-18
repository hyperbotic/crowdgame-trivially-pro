# ==================================================================================================================
class Localization

  kDefaultCode = "en-US"
  gCurrentCode = kDefaultCode

  # http://en.wikipedia.org/wiki/Language_localisation#Language_tags_and_codes

  kDictionary = [
    {key: "Play",                 code: "en-US", string: "Play"     }
    {key: "Play",                 code: "es-MX", string: "Juego"     }

    {key: "Play-Again",           code: "en-US", string: "Play Again"               }
#    {key: "Play-Again",           code: "es-MX", string: "Jugar de Nuevo"           }
    {key: "Play-Again",           code: "es-MX", string: "Juego"           }

    {key: "topic-selected",       code: "en-US", string: "topic selected"           }
    {key: "topic-selected",       code: "es-MX", string: "seleccion"        }

    {key: "topics-selected",      code: "en-US", string: "topics selected"          }
    {key: "topics-selected",      code: "es-MX", string: "selecciones"      }

    {key: "no-topics-selected",   code: "en-US", string: "No topics selected!"          }
    {key: "no-topics-selected",   code: "es-MX", string: "ninguna selección"      }

    {key: "content",              code: "en-US", string: "Content"                  }
    {key: "content",              code: "es-MX", string: "Contenido"                }

    {key: "add-select-trivia",    code: "en-US", string: "add & select trivia packs" }
    {key: "add-select-trivia",    code: "es-MX", string: "Agregar y seleccionar los paquetes de la trivia"}

    {key: "options",              code: "en-US", string: "Options"                  }
    {key: "options",              code: "es-MX", string: "Opciones"                 }

    {key: "change-game-settings", code: "en-US", string: "change game settings"     }
    {key: "change-game-settings", code: "es-MX", string: "Ajustes de cambio de juego"     }

    {key: "help",                 code: "en-US", string: "Help"                  }
    {key: "help",                 code: "es-MX", string: "Ayuda"                 }

    {key: "pause",                 code: "en-US", string: "pause"                  }
    {key: "pause",                 code: "es-MX", string: "pausa"                 }

    {key: "score-point",           code: "en-US", string: "Your Score: #\{score} Point" }
    {key: "score-point",           code: "es-MX", string: "Su puntuación:  #\{score} Punto" }

    {key: "score-points",          code: "en-US", string: "Your Score: #\{score} Points" }
    {key: "score-points",          code: "es-MX", string: "Su puntuación:  #\{score} Puntos" }

  ]

  # Game Paused: Juego pausado
  # Sound: sonido
  # On: sí
  # Off: no
  # Play: jugar
  # Continue Game: continuar el juego
  # End
  # Finish Game: terminar el juego / concluir el juego
  # New
  # New Game: nuevo juego
  # 
  #

  # ----------------------------------------------------------------------------------------------------------------
  @
  # ----------------------------------------------------------------------------------------------------------------
  @isValidLanguageCode: (languageCode)->
    code = switch languageCode.toLowerCase()
      when "en-us"
        "en-US"
      when "es-mx"
        "es-MX"
      else
        null

    code

  # ----------------------------------------------------------------------------------------------------------------
  @setLanguageCode: (languageCode = kDefaultCode)->

    gCurrentCode = if (l = Localization.isValidLanguageCode(languageCode))?
      l
    else
      kDefaultCode
    
    gCurrentCode

  # ----------------------------------------------------------------------------------------------------------------
  @getCurrentLanguageCode: ()-> gCurrentCode

  # ----------------------------------------------------------------------------------------------------------------
  @T: (key, dFault = "", context = null)->

    s = if (e = _.find(kDictionary, (m)=> (m.code is gCurrentCode) and (m.key is key)))?
      e.string
    else
      dFault

    Hy.Utils.String.replaceTokens(s, context)

# ==================================================================================================================

Hy.Localization = Localization