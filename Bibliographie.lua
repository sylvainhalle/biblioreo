-- =========================
-- Bibliographie.lua (LuaLaTeX)
-- =========================

-- Dépendances
local bibtex = require("lua-bibtex-parser")

-- Impression sûre vers TeX (évite U+000A dans la police)
local function safe_texprint(s)
  if not s then return end
  s = s:gsub("[\n\r]+", " ")  -- normalise les retours de ligne
  tex.print(s)
end

-- =========================
-- Utilitaires
-- =========================

local function trim(s)
  return (s and s:gsub("^%s+", ""):gsub("%s+$", "")) or ""
end

local function split(s, sep_pattern)
  local t = {}
  if not s or s == "" then return t end
  local start = 1
  while true do
    local i, j = s:find(sep_pattern, start)
    if not i then
      table.insert(t, trim(s:sub(start)))
      break
    end
    table.insert(t, trim(s:sub(start, i - 1)))
    start = j + 1
  end
  return t
end

local function get_field_case_insensitive(fields_dict, wanted)
  local lower_wanted = string.lower(wanted)
  for k, v in pairs(fields_dict) do
    if string.lower(k) == lower_wanted then
      return v and v.value or nil
    end
  end
  return nil
end

-- =========================
-- Groupes JabRef -> Arbre
-- =========================

local function new_node(name)
  return { name = name or "", children = {}, entries = {} }
end

local function ensure_child(node, part)
  part = trim(part)
  if part == "" then return node end
  local key = string.lower(part) -- clé canonique
  if not node.children[key] then
    node.children[key] = new_node(part)
  end
  return node.children[key]
end

local function parse_groups_field(groups_raw)
  if not groups_raw or trim(groups_raw) == "" then return {} end
  local paths = split(groups_raw, "[,;]+")
  local result = {}
  for _, path in ipairs(paths) do
    local norm = path:gsub("::", "/"):gsub(">", "/")
    local segs = split(norm, "/+")
    local cleaned = {}
    for _, s in ipairs(segs) do
      if s ~= "" then table.insert(cleaned, s) end
    end
    if #cleaned > 0 then table.insert(result, cleaned) end
  end
  return result
end

local function build_groups_tree(library)
  local root = new_node("(root)")
  for i = 1, #library.entries do
    local e = library.entries[i]
    local fields = e.fields_dict or {}
    local groups_raw = get_field_case_insensitive(fields, "groups")

    local paths = parse_groups_field(groups_raw)
    if #paths == 0 then
      local node = ensure_child(root, "_Sans groupe")
      table.insert(node.entries, i)
    else
      for _, segs in ipairs(paths) do
        local node = root
        for _, part in ipairs(segs) do
          node = ensure_child(node, part)
        end
        table.insert(node.entries, i)
      end
    end
  end
  return root
end

local function propagate_entries(node)
  local acc = {}
  for _, child in pairs(node.children) do
    local child_list = propagate_entries(child)
    for _, v in ipairs(child_list) do table.insert(acc, v) end
  end
  for _, v in ipairs(node.entries) do table.insert(acc, v) end
  node.entries_all = acc
  return acc
end

local function walk_tree(node, cb, path, depth)
  path = path or {}
  depth = depth or 0
  cb(path, node, depth)

  local keys = {}
  for k, _ in pairs(node.children) do table.insert(keys, k) end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local child = node.children[k]
    local new_path = {}
    for i=1,#path do new_path[i] = path[i] end
    table.insert(new_path, child.name)
    walk_tree(child, cb, new_path, depth + 1)
  end
end

-- =========================
-- Abréviation des auteurs
-- =========================

function shorten_authors(authors_field)
  if not authors_field or authors_field == "" then
    return ""
  end

  -- Découpage sur ' and ' (séparateur BibTeX)
  local authors = {}
  for a in authors_field:gmatch("([^%s][^%s]*.-)%s+and%s+") do
    table.insert(authors, a)
  end
  local last = authors_field:match("and%s+([^%s].-)$")
  if last then table.insert(authors, last) end
  if #authors == 0 then
    table.insert(authors, authors_field)
  end

  local function shorten_one(author)
    author = author:gsub("[{}]", ""):gsub("^%s*(.-)%s*$", "%1")
    local parts = {}
    for word in author:gmatch("%S+") do
      table.insert(parts, word)
    end
    if #parts == 1 then
      return parts[1]
    else
      local last = parts[#parts]
      local initials = ""
      for i = 1, #parts - 1 do
        initials = initials .. parts[i]:sub(1,1):upper() .. ". "
      end
      return initials .. last
    end
  end

  local n = #authors
  if n > 3 then
    return shorten_one(authors[1]) .. " \\textit{et al.\\@}"
  else
    local short = {}
    for _, a in ipairs(authors) do
      table.insert(short, shorten_one(a))
    end
    return table.concat(short, ", ")
  end
end

-- =========================
-- Impression d'une entrée
-- =========================

local function print_entry(i, library)
  local e = library.entries[i]
  local fields = e.fields_dict or {}

  local function fval(name)
    local f = fields[name]
    return f and f.value or nil
  end

  local au = fval("author")
  local yr = fval("year")
  local ti = fval("title")

  if au then safe_texprint("\\noindent " .. shorten_authors(au):gsub("[\n\r]", " ") .. ". ") end
  if yr then safe_texprint("(" .. yr .. "). ") end
  if ti then safe_texprint("\\titre{" .. ti .. "}") end

  safe_texprint("\\vskip 1pt")

  -- Chaque champ comment-* -> une table (auteur | commentaire)
  for key, fld in pairs(fields) do
    if type(fld) == "table" and fld["name"] and fld["name"]:find("^comment%-") then
      local author = string.gsub(fld["name"], "comment%-", "")

      -- Table : colonnes p{…} + boîtes top-alignées des deux côtés
      safe_texprint("\\begin{longtable}{@{}p{0.5in}p{5in}@{}}")

      -- Cellule 1 (gauche) : auteur dans \parbox[t]{0.5in}
      safe_texprint(
        "\\parbox[t]{0.5in}{\\vspace{0pt}" ..
        "\\auteur{" .. author .. "}{darkorange}{lightgoldenrodyellow}" ..
        "}"
        .. " & "
      )

      -- Cellule 2 (droite) : markdown dans une minipage top-alignée
      safe_texprint("\\begin{minipage}[t]{5in}\\vspace{0pt}")
      safe_texprint("\\begin{markdown}")
      safe_texprint(fld.value or "")
      safe_texprint("\\end{markdown}")
      safe_texprint("\\end{minipage}\\\\\\hline")

      safe_texprint("\\end{longtable}")
    end
  end

  safe_texprint("") -- séparation douce entre entrées
end

-- =========================
-- Lecture du .bib et sortie
-- =========================

local bib_file = io.open("Bibliographie.bib", "r")
local bib_content = bib_file:read("*a")
bib_file:close()

local library, exceptions = bibtex.parse(bib_content, {})

-- Construire + propager
local groups_root = build_groups_tree(library)
propagate_entries(groups_root)

-- Parcourir et imprimer
walk_tree(groups_root,
  function(path, node, depth)
    if depth == 0 then return end
    local title = table.concat(path, " / ")
    local heading_cmd = (depth == 1 and "\\section*" )
                     or (depth == 2 and "\\subsection*" )
                     or (depth == 3 and "\\subsubsection*" )
                     or "\\paragraph*"
    safe_texprint(heading_cmd .. "{" .. title .. "}")
    safe_texprint("\\vspace{2pt}")

    -- Choix : seulement les entrées du nœud courant
    local entries_to_print = node.entries
    -- Ou inclure descendants : local entries_to_print = node.entries_all

    for _, idx in ipairs(entries_to_print) do
      print_entry(idx, library)
    end
  end
)