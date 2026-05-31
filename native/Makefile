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

clean:
	rm -f src/*.o src/*/*.o src/*.d src/*/*.d bin/linux/*.so bin/windows/*.dll bin/macos/*.framework bin/web/*.wasm

.PHONY: all clean

-include $(DEPFILES)
