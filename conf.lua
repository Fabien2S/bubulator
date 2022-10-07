function love.conf(game)
    game.window.title = "Bubulator";
    --game.window.icon = "Assets/Icon.ico";
    game.window.resizable = true;
    game.window.vsync = 1;
    game.window.width = 800;
    game.window.height = 600;
    game.window.minwidth = 800;
    game.window.minheight = 600;
    game.window.depth = 24; -- took me way longer than it should have been to find this
end