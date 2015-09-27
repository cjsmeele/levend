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
import game;
import derelict.sdl2.sdl;
import derelict.sdl2.ttf;

void main() {
    DerelictSDL2.load();
    DerelictSDL2ttf.load();
    Game game = new Game;
    game.run;
}
