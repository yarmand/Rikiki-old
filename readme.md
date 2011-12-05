Rikiki
=

Version: 0.1

Rikiki is a very basic wiki engine using [markdown](http://daringfireball.net/projects/markdown/) as syntax.

Install
=
Rikiki use redcarpet to transform markdown
<code>
  gem install redcarpet
</code>

clone Rikiki each time you want a new wiki
<code>
  git clone git://github.com/yarmand/Rikiki.git
</code>

Usage
=
1. create a pages directory
2. start the deamon using
<code>
  ./rikiki.rb
</code>
3. begin to write .md files

result
=
- Rikiki will generate html version of pages in html directory as long it is running.
It will include template/header.html and template/footer.html

- An index of all pages is generated in **html/index.html**

- On top of each page, a table of content will be generated.

reset the index
-
delete file pages/index.md

regenerate all pages
-
1. stop Rikiki
2. delete **html** folder
3. delete file **pages_state.yml**
4. restart Rikiki

Todo
=
- clean the code
- make a gem
- make a textMate bundle

