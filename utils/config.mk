# utils version
VERSION = 1.0

# paths
PREFIX = $(HOME)/.local

# flags
CFLAGS  = -std=c99 -pedantic -Wall -Wextra -Wno-unused-parameter -Os -D_DEFAULT_SOURCE
LDFLAGS = -s

# compiler
CC = cc
