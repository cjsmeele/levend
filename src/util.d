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

import std.stdio;
import std.c.stdlib : exit;
import std.format   : formattedWrite;

void die(string reason, ...) {
    formattedWrite(
        stdout.LockingTextWriter(),
        "Died: " ~ reason, _arguments
    );
    exit(1);
}
