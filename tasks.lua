
--[[
this is a list of actions that can be performed by code to help maintain this site

is mp4 valid?

todo: spaces in expand.

]]


local tasks = {}

function tasks.build()
	-- this action builds index.html from the "images" folder

	require("tools")
	local lfs = require("lfs")
	
	local html = [[
<!DOCTYPE html> 
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>ever vigilant.</title>
    <style>
      :root {
        --dark: rgb(50, 50, 70);
      }
      body {
		background-color: var(--dark);
      }
    </style>
  </head>
  <body>
  	{{images}}
  </body>
</html>
]]

	local html_img = [[
    <img src="{{img}}" alt="a small creature with curly horns, a shaggy coat, and warm comforting eyes. She is wearing a cute purse as well. An aura of holiness emanates from her." width="300"/>
]]

	local currentdir = lfs.currentdir()
	lfs.chdir("remote")

	local images = listFiles("img")
	images = images:rep(function(img_path_from_root) return expand(html_img, {img=img_path_from_root}) end)

	html = expand(html, {images = images})
	print(html)
	write(html, "index.html")

	lfs.chdir(currentdir)
end


function tasks.localhost()
	local lfs = require("lfs")
	local currentdir = lfs.currentdir()
	lfs.chdir("remote")
	os.execute("py -m http.server")
	lfs.chdir(currentdir)
end

function tasks.upload()

	local inspect = require("inspect")

	require("tools")
	local auth = require("userpass")
	local api = require("neocities")(auth.user, auth.pass)
	local lfs = require("lfs")


	local currentdir = lfs.currentdir()
	lfs.chdir("remote")
	local files = listFiles(".")
	files = files:map(function(f) return {path=f} end)


	print(inspect(files))

	print("uploading")
	api.upload(files)
	lfs.chdir(currentdir)
end



tasks[...]()
