/*
 * Copyright (c) 2015, Chris Smeele.
 *
 * This file is part of Levend.
 *
 * Levend is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Levend is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Levend.  If not, see <http://www.gnu.org/licenses/>.
 */

import util;
import world;
import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import std.stdio;
import std.algorithm;

class Game {

private:
    SDL_Window   *sdlWindow;
    SDL_Renderer *sdlRenderer;

    World world = new World;

    uint targetFrameTime = 20; // in ms.
    uint minFrameDelay   = 2;  // .

    bool gridVisible = true;
    bool textVisible = true;
    int  cellSize    = 10;

    uint framesPerTick = 8; ///< FIXME: Sim should run on a separate thread.

    bool paused;

    XY viewportSize;
    XY viewportOffset;

    struct Color {
        ubyte red;
        ubyte green;
        ubyte blue;
        ubyte alpha;
    }

    Color colorBg   = { 240, 240, 240, 255 };
    Color colorFg   = {   0,   0,   0, 255 };
    Color colorGrid = { 200, 200, 200, 100 };

    TTF_Font *uiFont;

    //bool draggingLeft;
    bool draggingRight;

private:
    void setDrawColor(in Color color) {
        SDL_SetRenderDrawColor(sdlRenderer, color.red, color.green, color.blue, color.alpha);
    }

    bool isRegionVisible(in XY rpos) {
        return false;
    }

    void drawGrid () {
        if (cellSize < 6)
            return;

        setDrawColor(colorGrid);

        for (auto y=0; y<viewportSize.y; y+=cellSize)
            SDL_RenderDrawLine(
                sdlRenderer,
                0, y,
                viewportSize.x, y,
            );
        for (auto x=0; x<viewportSize.x; x+=cellSize)
            SDL_RenderDrawLine(
                sdlRenderer,
                x, 0,
                x, viewportSize.y,
            );
    }

    void drawRegion(in XY canvasXY, in XY regionXY) {
        auto region = world.getRegion(regionXY);
        if (region !is null && region.population > 0) {

            SDL_SetRenderDrawColor(sdlRenderer, 255, 255, 255, 255);
            SDL_Rect temp = {
                canvasXY.x,
                canvasXY.y,
                region.REGION_SIZE*cellSize,
                region.REGION_SIZE*cellSize
            };

            SDL_RenderFillRect(sdlRenderer, &temp);

            if ((regionXY.x & 1) ^ (regionXY.y & 1)) {
                SDL_SetRenderDrawColor(sdlRenderer, 255, 0, 0, 10);
                SDL_RenderFillRect(sdlRenderer, &temp);
            }

            setDrawColor(colorFg);
            foreach (int rowN; 0..region.REGION_SIZE) {
                foreach (int colN; 0..region.REGION_SIZE) {
                    if (region[rowN,colN]) {
                        SDL_Rect rect = {
                            canvasXY.x + colN * cellSize,
                            canvasXY.y + rowN * cellSize,
                            cellSize,
                            cellSize
                        };
                        SDL_RenderFillRect(
                            sdlRenderer,
                            &rect
                        );
                    }
                }
            }

            if (textVisible && cellSize > 3) {
                import std.string;
                string text = "(%d, %d) pop=%u".format(
                    regionXY.x * region.REGION_SIZE,
                    regionXY.y * region.REGION_SIZE,
                    region.population
                );
                SDL_Surface *textSurface = TTF_RenderUTF8_Solid(uiFont, text.toStringz, SDL_Color(255, 0, 0));
                assert(textSurface);

                SDL_Texture *textTexture = SDL_CreateTextureFromSurface(sdlRenderer, textSurface);

                SDL_Rect textRect = {
                    canvasXY.x + 6,
                    canvasXY.y + 2,
                    textSurface.w,
                    textSurface.h,
                };
                SDL_RenderCopy(sdlRenderer, textTexture, null, &textRect);

                SDL_DestroyTexture(textTexture);
                SDL_FreeSurface(textSurface);
            }
        }
    }

    void render() {
        setDrawColor(colorBg);
        SDL_RenderClear(sdlRenderer);

        setDrawColor(colorFg);

        // TODO: Render only visible regions.
        // TODO: Allow panning.
        foreach (rRow; 0..8) {
            foreach (rCol; 0..8) {
                drawRegion(
                    XY(rCol*Region.REGION_SIZE*cellSize, rRow*Region.REGION_SIZE*cellSize),
                    XY(rCol, rRow)
                );
            }
        }

        if (gridVisible)
            drawGrid;
    }

    void tick() {
        world.tick;
    }

public:
    void run() {
        initSDL;

        uint startTime = SDL_GetTicks(); ///< In ms.
        uint frameCount = 0;

        void placeBlock(int x, int y) {
            world.toggleCell(XY(x  , y  ));
            world.toggleCell(XY(x+1, y  ));
            world.toggleCell(XY(x+1, y+1));
            world.toggleCell(XY(x  , y+1));
        }
        void placeGlider(int x, int y) {
            world.toggleCell(XY(x+1, y  ));
            world.toggleCell(XY(x+2, y+1));
            world.toggleCell(XY(x  , y+2));
            world.toggleCell(XY(x+1, y+2));
            world.toggleCell(XY(x+2, y+2));
        }

        placeBlock(25, 20);
        placeGlider(34, 18);
        placeGlider(10, 31);

        world.flip;

        for (;;) {
            frameCount++;
            uint frameStartTime = SDL_GetTicks();

            SDL_Event e;
            while (SDL_PollEvent(&e)) {
                if (
                        e.type == SDL_QUIT
                    || (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_q)
                ) {
                    SDL_Quit();
                    return;
                } else if (e.type == SDL_WINDOWEVENT) {
                    if (e.window.event == SDL_WINDOWEVENT_RESIZED) {
                        SDL_GetWindowSize(sdlWindow, &viewportSize.x, &viewportSize.y);

                    }
                } else if (e.type == SDL_KEYDOWN) {
                    if (e.key.keysym.sym == SDLK_EQUALS) {
                        cellSize++;
                    } else if (e.key.keysym.sym == SDLK_MINUS) {
                        cellSize = max(1, cellSize - 1);
                    } else if (e.key.keysym.sym == SDLK_LEFTBRACKET) {
                        framesPerTick++;
                    } else if (e.key.keysym.sym == SDLK_RIGHTBRACKET) {
                        framesPerTick = max(1, framesPerTick-1);
                    } else if (e.key.keysym.sym == SDLK_3) {
                        gridVisible = !gridVisible;
                    } else if (e.key.keysym.sym == SDLK_4) {
                        textVisible = !textVisible;
                    } else if (e.key.keysym.sym == SDLK_PERIOD) {
                        paused = true;
                        tick;
                    } else if (e.key.keysym.sym == SDLK_SPACE) {
                        paused = !paused;
                    }
                } else if (e.type == SDL_MOUSEBUTTONDOWN) {
                    if (e.button.button == SDL_BUTTON_RIGHT) {
                        draggingRight = true;
                    } else if(e.button.button == SDL_BUTTON_LEFT) {
                        world.toggleCell(XY(
                            e.button.x / cellSize,
                            e.button.y / cellSize,
                        ));
                        world.getRegionAt(XY(
                            e.button.x / cellSize,
                            e.button.y / cellSize,
                        )).flip(true);
                    }
                } else if (e.type == SDL_MOUSEBUTTONUP) {
                    if (e.button.button == SDL_BUTTON_RIGHT) {
                        draggingRight = false;
                    } else if(e.button.button == SDL_BUTTON_LEFT) {
                    }
                } else if (e.type == SDL_MOUSEMOTION) {
                    if (draggingRight) {
                        viewportOffset.x += e.motion.xrel;
                        viewportOffset.y += e.motion.yrel;
                    }
                } else if (e.type == SDL_MOUSEWHEEL) {
                    if (e.wheel.y)
                        cellSize = max(1, cellSize + -e.wheel.y);
                }
            }

            // TODO: Run simulation in one or more separate threads.
            if (!paused && !(frameCount % framesPerTick))
                tick;

            render;
            SDL_RenderPresent(sdlRenderer);

            uint frameEndTime  = SDL_GetTicks();
            uint frameTime     = frameEndTime - frameStartTime;
             int frameTimeLeft = targetFrameTime - frameTime;
            debug (fps)
                writefln("Frame time %d ms  Time left: %d ms", frameTime, frameTimeLeft);
            SDL_Delay(max(min(frameTimeLeft, targetFrameTime), minFrameDelay));
        }
    }

private:
    void initSDL() {
        if (SDL_Init(SDL_INIT_VIDEO ) != 0)
            die("Could not init SDL");

        if (TTF_Init() != 0)
            die("Could not init TTF");

        // Can we use system fonts somehow?
        import std.file : exists;
        string ttfFilename = "OpenSans-Regular.ttf";
        assert(
            std.file.exists(ttfFilename),
              "Could not find font file '" ~ ttfFilename ~ "' in your CWD\n"
            ~ "(you can find it here: https://raw.githubusercontent.com/google/fonts/master/apache/opensans/OpenSans-Regular.ttf)"
        );

        import std.string : toStringz;

        uiFont = TTF_OpenFont(ttfFilename.toStringz, 12);
        if (uiFont == null)
            die("TTF_OpenFont error: %s", TTF_GetError());

        sdlWindow = SDL_CreateWindow(
            "levend",
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            640,
            480,
            SDL_WINDOW_RESIZABLE,
        );

        if (sdlWindow == null)
            die("SDL_CreateWindow error: %s", SDL_GetError());

        sdlRenderer = SDL_CreateRenderer(
            sdlWindow,
            -1,
            SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC,
        );

        if (sdlRenderer == null)
            die("SDL_CreateRenderer error: %s", SDL_GetError());

        SDL_SetRenderDrawBlendMode(sdlRenderer, SDL_BLENDMODE_BLEND);

        SDL_GetWindowSize(sdlWindow, &viewportSize.x, &viewportSize.y);
    }
}
