-- =========================
-- Bibliographie.lua (LuaLaTeX)
-- =========================

-- Dépendances
local bibtex = require("lua-bibtex-parser")
local md = require("markdown")
local convert = md.new()

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
      local node = ensure_child(root, "Sans groupe")
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

-- ========= utils =========
local function trim(s) return (s and s:gsub("^%s+",""):gsub("%s+$","")) or s end
local function unbrace(s)
  if type(s) ~= "string" then return s end
  s = trim(s)
  if s and #s >= 2 then
    local a,b = s:sub(1,1), s:sub(-1,-1)
    if (a == "{" and b == "}") or (a == '"' and b == '"') then
      return s:sub(2, -2)
    end
  end
  return s
end

local function lower(s) return type(s)=="string" and s:lower() or s end
local function emit(s)
  if _G.tex and tex.sprint then tex.sprint(s) else print(s) end
end

-- ========= robust get_field =========
local function get_field(entry, wanted_name)
  if type(entry) ~= "table" then return nil end
  if not wanted_name or wanted_name == "" then return nil end
  local wanted = wanted_name:lower()

  -- 0) parfois à la racine
  for k,v in pairs(entry) do
    if type(k)=="string" and k:lower()==wanted and type(v)=="string" then
      return unbrace(v)
    end
  end

  local f = entry.fields
  if type(f) ~= "table" then return nil end

  -- 1) dictionnaire: clés -> valeurs
  local is_list = (#f > 0 and type(f[1])=="table")
  if not is_list then
    for k,v in pairs(f) do
      if type(k)=="string" and k:lower()==wanted and type(v)=="string" then
        return unbrace(v)
      end
    end
  end

  -- 2) liste { {name=..., value=...}, ... }
  if is_list then
    for _,item in ipairs(f) do
      local name = lower(item.name or item.key)
      if name == wanted then
        local v = item.value or item.val or item.text
        if type(v)=="string" and v~="" then
          return unbrace(v)
        end
      end
    end
  end

  return nil
end

-- ===== Venue: extraction simple et robuste journal/booktitle =====
Venue = Venue or {}

function Venue._trim(s)  return type(s)=="string" and (s:gsub("^%s+",""):gsub("%s+$","")) or s end
function Venue._unbrace(s)
  if type(s) ~= "string" then return s end
  s = Venue._trim(s)
  if s and #s >= 2 then
    local a,b = s:sub(1,1), s:sub(-1)
    if (a=='{' and b=='}') or (a=='"' and b=='"') then
      return s:sub(2,-2)
    end
  end
  return s
end

-- Émission: LuaLaTeX => tex.sprint, sinon print
function Venue._emit(s)
  if _G.tex and tex.sprint then
    tex.sprint(tostring(s or ""))
  else
    print(tostring(s or ""))
  end
end

-- Récupère un champ:
--  - à la racine (entry[name])
--  - dans entry.fields dict (fields[name])
--  - dans entry.fields liste { {name=..., value=...}, ... }
function Venue.get_field(entry, name)
  if type(entry) ~= "table" or not name then return nil end
  local lname = name:lower()

  -- racine
  for k,v in pairs(entry) do
    if type(k)=="string" and k:lower()==lname and type(v)=="string" then
      return Venue._unbrace(v)
    end
  end

  local f = entry.fields
  if type(f) ~= "table" then return nil end

  -- dict
  local is_list = (#f > 0 and type(f[1])=="table")
  if not is_list then
    for k,v in pairs(f) do
      if type(k)=="string" and k:lower()==lname and type(v)=="string" then
        return Venue._unbrace(v)
      end
    end
  end

  -- liste {name,value}
  if is_list then
    for _, item in ipairs(f) do
      local ik = item and (item.name or item.key)
      if type(ik)=="string" and ik:lower()==lname then
        local v = item.value or item.val or item.text
        if type(v)=="string" and v~="" then
          return Venue._unbrace(v)
        end
      end
    end
  end

  return nil
end
Venue._get_field = Venue.get_field

-- Imprime: journal si présent, sinon booktitle, sinon vide
function Venue.print(entry)
  local ok, err = pcall(function()
    local et = Venue._get_type(entry)

    if et == "article" then
      local v = Venue._get_field(entry, "journal") or Venue._get_field(entry, "journaltitle")
      Venue._emit(v or "")
      return
    elseif et == "inproceedings" then
      local bt = Venue._get_field(entry, "booktitle")
      local acro = Venue._extract_acronym(bt or "")
      Venue._emit(acro or bt or "")
      return
    end

    -- Fallback for other types or unknown:
    local v =
      Venue._get_field(entry, "journal") or
      Venue._get_field(entry, "journaltitle") or
      Venue._get_field(entry, "booktitle")
    Venue._emit(v or "")
  end)
  if not ok then
    Venue._emit("")
    Venue._emit("% Venue.print error: "..tostring(err))
  end
end

function Venue._get_type(entry)
  -- pull a type string from entry and normalize
  local raw = Venue._get_field and Venue._get_field(entry, "type") or nil
  raw = raw or (type(entry.type)=="string" and entry.type) or (type(entry.entry_type)=="string" and entry.entry_type) or (type(entry.entryType)=="string" and entry.entryType) or ""
  raw = tostring(raw):gsub("^@+","")           -- remove leading '@'
  raw = raw:match("^[A-Za-z]+") or raw         -- take leading word
  return (raw and raw:lower()) or ""
end

-- Extract a plausible acronym from a booktitle
function Venue._extract_acronym(booktitle)
  if not booktitle or booktitle == "" then return nil end
  booktitle = Venue._unbrace(booktitle)
  local blacklist = { IEEE = true, ACM = true }

  local function split_on_delims(tok)
    local parts = {}
    for p in tok:gmatch("[^/%+%-%&]+") do table.insert(parts, p) end
    return parts
  end

  local function collect_from(text, acc)
    -- uppercase sequences with digits and common separators (ESEC/FSE, S&P, ICSE2024)
    for tok in text:gmatch("(%u[%u%d/%+%-%&]+)") do
      local keep, only_blacklisted = false, true
      for _, part in ipairs(split_on_delims(tok)) do
        part = part:upper()
        if not blacklist[part] and part:match("%u") then keep = true end
        if not blacklist[part] then only_blacklisted = false end
      end
      if keep and not only_blacklisted then table.insert(acc, tok) end
    end
  end

  local candidates = {}
  collect_from(booktitle, candidates)
  for inside in booktitle:gmatch("%((.-)%)") do collect_from(inside, candidates) end

  if #candidates == 0 then return nil end
  table.sort(candidates, function(a,b) return #a > #b end) -- prefer longer (ESEC/FSE over FSE)
  return candidates[1]
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
  local ky = e.key or nil
  local fi = fval("file")

  if ky then
    safe_texprint("\\bibkey{" .. ky .. "}")
  end
  safe_texprint("\\begin{insidebox}\n")
  if au then safe_texprint("\\noindent " .. shorten_authors(au):gsub("[\n\r]", " ") .. ". ") end
  if yr then safe_texprint("(" .. yr .. "). ") end
  if ti then
    if fi then
      local filename = string.match(fi, ":(.-%.pdf):") or ""
      safe_texprint("\\href{run:Documents/" .. filename .. "}{\\underLine{\\titre{" .. ti .. "}}}.")
    else
      safe_texprint("\\titre{" .. ti .. "}")
    end
  end
  safe_texprint("\\textit{")
  Venue.print(e)
  safe_texprint("}")
  

  safe_texprint("\\vskip 12pt")
  if fields["llmsummary"] then
    safe_texprint("\\begin{longtable}{@{}p{0.5in}p{5.375in}@{}}")
    --safe_texprint("{\\small \\og{}" .. convert(fields["llmsummary"].value) .. "\\fg{} \\raisebox{-2pt}{\\includegraphics[height=9pt]{chatgpt-seeklogo}}}\n")
          safe_texprint("\\chatbox{} & ")
        safe_texprint("\\begin{minipage}[t]{5.375in}\\vspace{-15pt}\\small")
      --safe_texprint("\\begin{markdown}")
      safe_texprint(convert(fields["llmsummary"].value or ""))
      --safe_texprint("\\end{markdown}")
      safe_texprint("\\end{minipage}")
      safe_texprint("\\end{longtable}")

  end

  -- Chaque champ comment-* -> une table (auteur | commentaire)
  for key, fld in pairs(fields) do
    if type(fld) == "table" and fld["name"] and fld["name"]:find("^comment%-") then
      local author = string.gsub(fld["name"], "comment%-", "")

      -- Table : colonnes p{…} + boîtes top-alignées des deux côtés
      safe_texprint("\\begin{longtable}{@{}p{0.5in}p{5.375in}@{}}")

      -- Cellule 1 (gauche) : auteur dans \parbox[t]{0.5in}
        safe_texprint(
          "\\parbox[t]{0.5in}{\\vspace{0pt}" ..
          "\\auteur{" .. author .. "}{darkorange}{lightgoldenrodyellow}" ..
          "}"
          .. " & "
        )

      -- Cellule 2 (droite) : markdown dans une minipage top-alignée
      safe_texprint("\\begin{minipage}[t]{5.375in}\\vspace{-15pt}\\small")
      --safe_texprint("\\begin{markdown}")
      safe_texprint("\\color{paleblack} " .. convert(fld.value or ""))
      --safe_texprint("\\end{markdown}")
      safe_texprint("\\end{minipage}")
      safe_texprint("\\end{longtable}")
    end
  end
  safe_texprint("\\end{insidebox}")
  safe_texprint("\\vspace{10pt}") -- séparation douce entre entrées
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