-- Dependencies
local bibtex = require("lua-bibtex-parser")

-- Abréger le champ author d'une entrée BibTeX
-- Exemple d'entrée: "John Smith and Jane Doe and Foo Bar Baz"
-- Exemple de sortie: "J. Smith, J. Doe, F. Baz" ou "J. Smith et al."

function shorten_authors(authors_field)
  if not authors_field or authors_field == "" then
    return ""
  end

  -- Découpe les auteurs selon " and " (séparateur BibTeX)
  local authors = {}
  for a in authors_field:gmatch("([^%s][^%s]*.-)%s+and%s+") do
    table.insert(authors, a)
  end
  -- Dernier auteur (car gmatch ci-dessus ne prend pas le dernier)
  local last = authors_field:match("and%s+([^%s].-)$")
  if last then table.insert(authors, last) end

  -- Si un seul auteur sans "and"
  if #authors == 0 then
    table.insert(authors, authors_field)
  end

  -- Convertit chaque auteur en "Initiales Nom"
  local function shorten_one(author)
    -- Enlève accolades et espaces parasites
    author = author:gsub("[{}]", ""):gsub("^%s*(.-)%s*$", "%1")

    -- Découpe en mots
    local parts = {}
    for word in author:gmatch("%S+") do
      table.insert(parts, word)
    end

    if #parts == 1 then
      return parts[1] -- juste un nom
    else
      local last = parts[#parts]
      local initials = ""
      for i = 1, #parts - 1 do
        initials = initials .. parts[i]:sub(1,1):upper() .. ". "
      end
      return initials .. last
    end
  end

  -- Abrège selon le nombre d’auteurs
  local n = #authors
  if n > 3 then
    return shorten_one(authors[1]) .. " et al."
  else
    local short = {}
    for _, a in ipairs(authors) do
      table.insert(short, shorten_one(a))
    end
    return table.concat(short, ", ")
  end
end

-- Parse the JabRef document
local bib_file = io.open("Bibliographie.bib", "r")
local bib_content = bib_file:read("*a")
bib_file:close()
local dict = {}
local library, exceptions = bibtex.parse(bib_content, {})
for i = 1, #library.entries do
  local fields = library.entries[i].fields_dict
  tex.print("\\noindent " .. shorten_authors(fields["author"].value):gsub("[\n\r]", " ") .. ". ")
  tex.print("(" .. fields["year"].value .. "). ")
  tex.print("\\titre{" .. fields["title"].value .. "}\n")
  if (fields["comment-sylvain"]) then
    --tex.print("\\begin{markdown}\n" .. fields["comment-sylvain"].value .. "\n\\end{markdown}")
    tex.print("\\begin{minipage}{6.5in}\\small\n")
    tex.print("\\begin{markdown}\n")
    tex.print(fields["comment-sylvain"].value)
    tex.print("\n\\end{markdown}\n")
    tex.print("\\end{minipage}\n")
  end
  tex.print("\n\n");
end