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
import std.stdio;

struct XY { int x, y; }

enum Direction {
    NORTHWEST,
    NORTH,
    NORTHEAST,
    EAST,
    SOUTHEAST,
    SOUTH,
    SOUTHWEST,
    WEST,
}

class Region {
public:
    enum REGION_SIZE = 32;

private:
    bool dirty;           ///< Whether this region has changed since the last flip().
    bool required;        ///< Whether we have an active neighbor.
    bool needsEvaluation; ///< Whether a neighbor region is active at a connecting edge or corner.

    bool newRequired;        ///< Set by neighbors and applied to `required` on the next world flip().
    bool newNeedsEvaluation; ///< Set by neighbors and applied to `needsEvaluation` on the next world flip().

    bool    grid[REGION_SIZE][REGION_SIZE];
    bool newGrid[REGION_SIZE][REGION_SIZE];

    ulong   _population = 0;
    ulong newPopulation = 0;

    World world;
    XY _location;

    @property population(ulong n) { _population = n;  }
    @property location(XY xy)     { _location   = xy; }

    Region getNeighbor(int relX, int relY) {
        auto neighbor = world.getRegion(XY(location.x + relX, location.y + relY), true);
        neighbor.required = true;
        return neighbor;
    }

public:
    @property active()     { return dirty || _population || needsEvaluation; }
    @property population() { return _population; }
    @property location()   { return _location; }

    bool[REGION_SIZE] getEdge(Direction side)() {
        static if (side == Direction.NORTH) {
            return grid[0];
        } else static if (side == Direction.SOUTH) {
            return grid[REGION_SIZE - 1];
        } else static if (side == Direction.EAST) {
            bool[REGION_SIZE] ret;
            foreach (i, row; grid)
                ret[i] = row[REGION_SIZE - 1];
            return ret;
        } else static if (side == Direction.WEST) {
            bool[REGION_SIZE] ret;
            foreach (i, row; grid)
                ret[i] = row[0];
            return ret;
        } else { static assert(false); }
    }

    bool getCorner(Direction dir)() {
        static if (dir == Direction.NORTHWEST)
            return grid[0][0];
        else static if (dir == Direction.NORTHEAST)
            return grid[0][REGION_SIZE-1];
        else static if (dir == Direction.SOUTHWEST)
            return grid[REGION_SIZE-1][0];
        else static if (dir == Direction.SOUTHEAST)
            return grid[REGION_SIZE-1][REGION_SIZE-1];
        else
            static assert(false);
    }

    const bool opIndex(size_t y, size_t x) { return grid[y][x]; }

    void opIndexAssign(bool newValue, size_t y, size_t x) {
        auto old     =    grid[y][x];
        auto current = newGrid[y][x];
        if (current ^ newValue) {
            newPopulation += newValue ? 1 : -1;
            newGrid[y][x] = newValue;
        }
        if (old ^ newValue)
            dirty = true;
    }

    void nudgeNeighbors() {
        // Mark all neighbor regions as needing evaluation on the next tick.

        getNeighbor(-1, -1).needsEvaluation = true;
        getNeighbor( 0, -1).needsEvaluation = true;
        getNeighbor( 1, -1).needsEvaluation = true;
        getNeighbor( 1,  0).needsEvaluation = true;
        getNeighbor( 1,  1).needsEvaluation = true;
        getNeighbor( 0,  1).needsEvaluation = true;
        getNeighbor(-1,  1).needsEvaluation = true;
        getNeighbor(-1,  0).needsEvaluation = true;
    }

    void evolve() {
        bool[REGION_SIZE+2][REGION_SIZE+2] g; ///< Grid including edges / corners of neighbor regions.

        // Copy our own cells into the grid's center.
        foreach (y, row; grid)
            foreach (x, n; row)
                g[y+1][x+1] = n;

        // Copy neighbor's cells into the grid's edges and corners.
        auto northwest = getNeighbor(-1, -1); g[0][0]                         = northwest.getCorner!(Direction.SOUTHEAST);
        auto north     = getNeighbor( 0, -1);
        auto northeast = getNeighbor( 1, -1); g[0][REGION_SIZE+1]             = northeast.getCorner!(Direction.SOUTHWEST);
        auto east      = getNeighbor( 1,  0);
        auto southeast = getNeighbor( 1,  1); g[REGION_SIZE+1][REGION_SIZE+1] = southeast.getCorner!(Direction.NORTHWEST);
        auto south     = getNeighbor( 0,  1);
        auto southwest = getNeighbor(-1,  1); g[REGION_SIZE+1][0]             = southwest.getCorner!(Direction.NORTHEAST);
        auto west      = getNeighbor(-1,  0);

        g[REGION_SIZE+1][1..REGION_SIZE+1] = south.getEdge!(Direction.NORTH)[];
        g[0][1..REGION_SIZE+1]             = north.getEdge!(Direction.SOUTH)[];

        foreach (y, n; west.getEdge!(Direction.EAST))
            g[y+1][0] = n;

        foreach (y, n; east.getEdge!(Direction.WEST))
            g[y+1][REGION_SIZE+1] = n;

        // Evaluate each cell.
        foreach (y, row; grid) {
            auto gy = y + 1;
            foreach (x, cell; row) {
                auto gx = x + 1;
                uint neighbors =
                      g[gy-1][gx-1]
                    + g[gy-1][gx  ]
                    + g[gy-1][gx+1]
                    + g[gy  ][gx-1]
                    //
                    + g[gy  ][gx+1]
                    + g[gy+1][gx-1]
                    + g[gy+1][gx  ]
                    + g[gy+1][gx+1];

                bool cellAlive = false;

                // TODO: Make game rules run-time configurable.
                version (highlife) {
                    // High life.
                    pragma(msg, "Compiling with ruleset: High Life (B36/S23)");
                    if (cell) {
                        if (neighbors < 2 || neighbors > 3) {
                            this[y,x] = false;
                        } else {
                            cellAlive = true;
                        }
                    } else if (!cell && (neighbors == 3 || neighbors == 6)) {
                        this[y,x] = true;
                        cellAlive = true;
                    }
                } else version (lfod) {
                    pragma(msg, "Compiling with ruleset: Live Free or Die (B2/S0)");
                    // Live free or die.
                    if (cell) {
                        if (neighbors) {
                            this[y,x] = false;
                        } else {
                            cellAlive = true;
                        }
                    } else if (!cell && neighbors == 2) {
                        this[y,x] = true;
                        cellAlive = true;
                    }
                } else {
                    // Conway's game of life.
                    pragma(msg, "Compiling with ruleset: Conway's Game of Life (B3/S23)");
                    if (cell) {
                        if (neighbors < 2 || neighbors > 3) {
                            this[y,x] = false;
                        } else {
                            cellAlive = true;
                        }
                    } else if (!cell && neighbors == 3) {
                        this[y,x] = true;
                        cellAlive = true;
                    }
                }

                // Make sure neighbor regions get evaluated on the next tick if
                // we have a live cell on their border.
                if (cellAlive) {
                    if (y == 0) {
                        north.newNeedsEvaluation = true;
                        if (x == 0)
                            northwest.newNeedsEvaluation = true;
                        else if (x == REGION_SIZE-1)
                            northeast.newNeedsEvaluation = true;
                    } else if (y == REGION_SIZE-1) {
                        south.newNeedsEvaluation = true;
                        if (x == 0)
                            southwest.newNeedsEvaluation = true;
                        else if (x == REGION_SIZE-1)
                            southeast.newNeedsEvaluation = true;
                    }
                    if (x == 0)
                        west.newNeedsEvaluation = true;
                    else if (x == REGION_SIZE-1)
                        east.newNeedsEvaluation = true;
                }
            }
        }
    }

    void flip(bool independent = false) {
        if (dirty) {
            // Apply changes from the last evolution.
            grid       = newGrid[];
            population = newPopulation;
            dirty      = false;
        }
        if (independent) {
            // This region was flipped by itself, do not update flags involving
            // relations to other regions.
        } else {
            needsEvaluation    = newNeedsEvaluation;
            newNeedsEvaluation = false;
            required    = newRequired;
            newRequired = false;
        }
    }

    this(World world, in XY location) {
        this.location = location;
        this.world    = world;
    }
}

class World {
private:
    Region[XY] regions; ///< Map coordinates to regions.

    Region spawnRegion(in XY rXY) {
        debug (region)
            writefln("Spawning region (%d,%d)", rXY.x, rXY.y);
        return regions[rXY] = new Region(this, rXY);
    }

public:
    Region getRegion(in XY rXY, bool create = false) {
        if (rXY in regions)
            return regions[rXY];
        else if (create)
            return spawnRegion(rXY);
        else
            return null;
    }

    Region getRegionAt(in XY xy, bool create = false) {
        return getRegion(XY(xy.x / Region.REGION_SIZE, xy.y / Region.REGION_SIZE), create);
    }

    void flip() {
        XY[] inactiveXYs;

        foreach (xy, r; regions) {
            if (r.active || r.required) {
                r.flip;
            } else {
                inactiveXYs ~= xy;
            }
        }

        foreach (xy; inactiveXYs) {
            debug (region)
                writefln("Removing inactive region (%d,%d)", xy.x, xy.y);
            regions.remove(xy);
        }
    }

    void toggleCell(in XY xy) {
        auto r = getRegionAt(xy, true);

        // FIXME: Only apply `newNeedsEvaluation = true` to applicable
        //        neighbors to avoid unnecessary spawning and despawning of
        //        their neighbor regions.
        r.nudgeNeighbors;

        XY localXY = { xy.x % r.REGION_SIZE, xy.y % r.REGION_SIZE };
        r[localXY.y, localXY.x] = !r[localXY.y, localXY.x];
    }

    void tick() {
        Region[XY] currentRegions = regions.dup;
        foreach (xy, r; currentRegions) {
            if (r.active)
                r.evolve;
        }
        flip;
        write(".");
        stdout.flush;
    }
}
