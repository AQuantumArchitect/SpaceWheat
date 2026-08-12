CXX = g++
CXXFLAGS = -std=c++17 -fPIC -O2 -march=x86-64 \
           -I./include \
           -I./include/godot_cpp \
           -I./include/gdextension \
           -DLINUX_ENABLED -DUNIX_ENABLED -DGDEXTENSION \
           -DSPACEWHEAT_WITH_GODOT \
           -pthread

LDFLAGS = -shared ./lib/libgodot-cpp.linux.template_release.x86_64.a -pthread

SOURCES = $(wildcard src/*.cpp) $(wildcard src/*/*.cpp)
OBJECTS = $(SOURCES:.cpp=.o)
DEPFILES = $(OBJECTS:.o=.d)
TARGET = bin/linux/libquantummatrix.linux.template_release.x86_64.so

all: $(TARGET)

$(TARGET): | bin/linux

bin/linux:
	mkdir -p bin/linux

$(TARGET): $(OBJECTS)
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)
	@echo ""
	@echo "✓ Build complete: $(TARGET)"
	@ls -lh bin/linux/*.so

%.o: %.cpp
	@echo "Compiling $<..."
	$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

# Clean ONLY what this Makefile builds: the Linux objects and the Linux .so.
#
# It used to also delete bin/windows/*.dll, bin/macos/*.framework and
# bin/web/*.wasm — outputs it does not produce and cannot rebuild. Since
# build-all-platforms.sh runs `make clean` before every Linux extension build,
# building desktop silently destroyed the web extension. That went unnoticed
# only because the web extension had never been built; the moment it existed,
# one desktop build deleted it and the next web export would have shipped a
# bundle with no physics in it.
#
# A lane cleans its own outputs. Cross-platform artifacts belong to their own
# lanes (Makefile.windows, the em++ rule in build-all-platforms.sh).
clean:
	rm -f src/*.o src/*/*.o src/*.d src/*/*.d bin/linux/*.so

.PHONY: all clean

-include $(DEPFILES)
