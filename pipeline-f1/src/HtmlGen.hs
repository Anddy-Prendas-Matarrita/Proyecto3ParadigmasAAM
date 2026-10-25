-- | @brief Generacion de la interfaz web (index.html) a partir del modelo intermedio.
--
--   La pagina no se escribe a mano: cada seccion se construye con los datos
--   del Problem validado, por lo que cambiar problema.txt regenera la interfaz.
module HtmlGen (generateHtml) where

import PrologGen (entityFact, generateKnowledge, quoteAtom, relationFact, ruleCode)
import QueryGen (Query (..), suggestedQueries)
import Types

-- | @brief Escapa un texto para insertarlo de forma segura en HTML.
--   @param s Texto original.
--   @return Texto con los caracteres especiales convertidos en entidades HTML.
esc :: String -> String
esc = concatMap go
  where
    go '<'  = "&lt;"
    go '>'  = "&gt;"
    go '&'  = "&amp;"
    go '"'  = "&quot;"
    go '\'' = "&#39;"
    go c    = [c]

-- | @brief Envuelve un contenido en una etiqueta HTML.
--   @param t Nombre de la etiqueta.
--   @param body Contenido ya escapado.
--   @return Elemento HTML.
tag :: String -> String -> String
tag t body = "<" ++ t ++ ">" ++ body ++ "</" ++ t ++ ">"

-- | @brief Construye una tabla HTML con celdas ya escapadas.
--   @param heads Encabezados de columna.
--   @param rows Filas de la tabla.
--   @return Tabla HTML, o un aviso si no hay filas.
table :: [String] -> [[String]] -> String
table _ [] = "<p class='empty'>(ninguno)</p>"
table heads rows =
  "<div class='scroll'><table>"
    ++ tag "thead" (tag "tr" (concatMap (tag "th") heads))
    ++ tag "tbody" (concatMap (tag "tr" . concatMap (tag "td")) rows)
    ++ "</table></div>"

-- | @brief Construye una seccion de la pagina con identificador y titulo.
--   @param ident Identificador usado por el menu de navegacion.
--   @param title Titulo de la seccion.
--   @param body Contenido HTML de la seccion.
--   @return Elemento section.
section :: String -> String -> String -> String
section ident title body =
  "<section id='" ++ ident ++ "'><h2>" ++ esc title ++ "</h2>" ++ body ++ "</section>"

-- | @brief Muestra un texto como bloque de codigo preformateado.
--   @param s Texto sin escapar.
--   @return Elemento pre con el texto escapado.
pre :: String -> String
pre s = "<pre>" ++ esc s ++ "</pre>"

-- | @brief Obtiene el tipo y el nombre de una entidad para mostrarlos en la tabla.
--   @param e Entidad.
--   @return Par con el tipo y el nombre.
entityInfo :: Entity -> (String, String)
entityInfo (Person n)  = ("persona", n)
entityInfo (Course n)  = ("curso", n)
entityInfo (Teacher n) = ("docente", n)

-- | @brief Obtiene el nombre y los argumentos de una relacion para mostrarlos en la tabla.
--   @param r Relacion.
--   @return Tripleta con el nombre de la relacion, el origen y el destino.
relationInfo :: Relation -> (String, String, String)
relationInfo (Takes a b)   = ("lleva", a, b)
relationInfo (Teaches a b) = ("imparte", a, b)
relationInfo (Passes a b)  = ("aprueba", a, b)

-- | @brief Convierte un mensaje de validacion en un elemento de lista.
--   @param m Mensaje de error o advertencia.
--   @return Elemento li con la clase de color segun la gravedad.
messageItem :: Message -> String
messageItem m = "<li class='" ++ cls ++ "'>" ++ esc loc ++ esc (description m) ++ "</li>"
  where
    cls = case severity m of
      SevError   -> "err"
      SevWarning -> "warn"
    loc = maybe "[general] " (\n -> "[línea " ++ show n ++ "] ") (messageLine m)

-- | @brief Construye una tarjeta de resumen con un numero y su etiqueta.
--   @param label Etiqueta de la tarjeta.
--   @param val Valor mostrado.
--   @return Elemento HTML de la tarjeta.
card :: String -> String -> String
card label val =
  "<div class='card'><span>" ++ esc val ++ "</span>" ++ esc label ++ "</div>"

-- | @brief Hoja de estilos embebida en la pagina.
css :: String
css = unlines
  [ "body{font-family:system-ui,sans-serif;margin:0;background:#f4f5f7;color:#1c1e21}"
  , "header{background:#2d3a55;color:#fff;padding:20px 32px}"
  , "header h1{margin:0;font-size:1.5rem}header p{margin:4px 0 0;opacity:.8}"
  , "nav{background:#fff;padding:10px 32px;border-bottom:1px solid #ddd;position:sticky;top:0}"
  , "nav a{margin-right:16px;color:#2d3a55;text-decoration:none;font-weight:600}"
  , "main{max-width:1000px;margin:0 auto;padding:16px 24px}"
  , "section{background:#fff;border-radius:8px;padding:8px 20px 20px;margin:16px 0;box-shadow:0 1px 3px #0001}"
  , ".cards{display:flex;gap:12px;flex-wrap:wrap;margin:16px 0}"
  , ".card{background:#fff;border-radius:8px;padding:12px 20px;box-shadow:0 1px 3px #0001;min-width:120px}"
  , ".card span{display:block;font-size:1.6rem;font-weight:700;color:#2d3a55}"
  , "table{border-collapse:collapse;width:100%}th,td{text-align:left;padding:6px 10px;border-bottom:1px solid #eee}"
  , "th{background:#eef0f4}pre{background:#1e1e2e;color:#d6e2ff;padding:14px;border-radius:6px;overflow:auto;font-size:.85rem}"
  , "code{background:#eef0f4;padding:2px 6px;border-radius:4px}.scroll{overflow:auto}"
  , ".err{color:#b00020}.warn{color:#9a6700}.empty{color:#777}.ok{color:#1a7f37;font-weight:700}"
  , "button{cursor:pointer;border:1px solid #2d3a55;background:#fff;border-radius:4px;padding:2px 10px}"
  ]

-- | @brief JavaScript embebido que copia una consulta al portapapeles.
script :: String
script = unlines
  [ "function copyQ(b){navigator.clipboard.writeText(b.dataset.q);"
  , "var t=b.textContent;b.textContent='Copiado';setTimeout(function(){b.textContent=t},1200)}"
  ]

-- | @brief Genera el texto completo de index.html.
--   Muestra entidades, relaciones, hechos, reglas, consultas sugeridas,
--   errores, advertencias y el contenido de conocimiento.pl.
--   @param p Problema ya validado.
--   @return Documento HTML completo.
generateHtml :: Problem -> String
generateHtml p = unlines
  [ "<!DOCTYPE html>"
  , "<html lang='es'><head><meta charset='utf-8'>"
  , "<meta name='viewport' content='width=device-width,initial-scale=1'>"
  , "<title>Pipeline Haskell - Prolog</title>"
  , "<style>" ++ css ++ "</style></head><body>"
  , "<header><h1>Pipeline Funcional-Lógico: Haskell &rarr; Prolog &rarr; UI</h1>"
  , "<p>Dominio académico. Página generada automáticamente a partir del archivo de entrada.</p></header>"
  , "<nav>" ++ concat
      [ "<a href='#entidades'>Entidades</a>", "<a href='#relaciones'>Relaciones</a>"
      , "<a href='#hechos'>Hechos</a>", "<a href='#reglas'>Reglas</a>"
      , "<a href='#consultas'>Consultas</a>", "<a href='#avisos'>Avisos</a>"
      , "<a href='#fuente'>conocimiento.pl</a>" ] ++ "</nav>"
  , "<main>"
  , "<div class='cards'>" ++ concat
      [ card "entidades" (show (length (entities p)))
      , card "relaciones" (show (length (relations p)))
      , card "reglas" (show (length (requestedRules p)))
      , card "errores" (show (length (errors p)))
      , card "advertencias" (show (length (warnings p))) ] ++ "</div>"
  , section "entidades" "Entidades detectadas" entitiesHtml
  , section "relaciones" "Relaciones generadas" relationsHtml
  , section "hechos" "Hechos Prolog producidos" (pre factsText)
  , section "reglas" "Reglas generadas" rulesHtml
  , section "consultas" "Consultas sugeridas" queriesHtml
  , section "avisos" "Errores y advertencias" messagesHtml
  , section "fuente" "Contenido de conocimiento.pl" (pre (generateKnowledge p))
  , "</main><script>" ++ script ++ "</script></body></html>"
  ]
  where
    entitiesHtml = table ["Línea", "Tipo", "Nombre", "Átomo Prolog"]
      [ [ show (srcLine a), esc k, esc n, "<code>" ++ esc (quoteAtom n) ++ "</code>" ]
      | a <- entities p, let (k, n) = entityInfo (value a) ]

    relationsHtml = table ["Línea", "Relación", "Origen", "Destino"]
      [ [ show (srcLine a), esc r, esc x, esc y ]
      | a <- relations p, let (r, x, y) = relationInfo (value a) ]

    factsText = unlines $
      concat [ ["% linea " ++ show (srcLine a) ++ ": " ++ srcText a, entityFact (value a)]
             | a <- entities p ]
      ++ concat [ ["% linea " ++ show (srcLine a) ++ ": " ++ srcText a, relationFact (value a)]
                | a <- relations p ]

    rulesHtml
      | null (requestedRules p) = "<p class='empty'>(ninguna)</p>"
      | otherwise = concat
          [ "<h3>" ++ esc (value r) ++ "</h3>" ++ pre (unlines (ruleCode (value r)))
          | r <- requestedRules p ]

    queriesHtml = table ["#", "Descripción", "Consulta", ""]
      [ [ show n, esc (queryDesc q), "<code>?- " ++ esc (queryGoal q) ++ ".</code>"
        , "<button data-q='" ++ esc ("?- " ++ queryGoal q ++ ".") ++ "' onclick='copyQ(this)'>Copiar</button>" ]
      | (n, q) <- zip [1 :: Int ..] (suggestedQueries p) ]

    messagesHtml
      | null (errors p) && null (warnings p) = "<p class='ok'>Sin errores ni advertencias.</p>"
      | otherwise = "<ul>" ++ concatMap messageItem (errors p ++ warnings p) ++ "</ul>"
