# git submodule foreach git reset --hard
# git submodule foreach --recursive git reset --hard
# git submodule foreach --recursive git clean -x -f -d
cd boost
.\bootstrap.bat
.\b2.exe link=static runtime-link=static threading=multi address-model=64 -a --layout=versioned
cd ..\mpir\msvc\vs22
.\msbuild.bat gc LIB x64 Release
cd ..\..\..\mpfr\build.vs22\lib_mpfr
msbuild /p:Configuration=Release /p:Platform=x64 lib_mpfr.vcxproj
cd ..\..\..\ledger
cmake -DCMAKE_BUILD_TYPE:STRING="Release" -DUSE_PYTHON=OFF -DBUILD_LIBRARY=OFF -DMPFR_LIB:FILEPATH="../../mpfr/build.vs22/lib/x64/Release/mpfr" -DGMP_LIB:FILEPATH="../../mpir/lib/x64/Release/mpir" -DMPFR_PATH:PATH="../mpfr/lib/x64/Release" -DGMP_PATH:PATH="../mpir/lib/x64/Release" -DBUILD_DOCS:BOOL="0" -DHAVE_REALPATH:BOOL="0" -DHAVE_GETPWUID:BOOL="0" -DHAVE_GETPWNAM:BOOL="0" -DHAVE_IOCTL:BOOL="0" -DHAVE_ISATTY:BOOL="0" -DBOOST_ROOT:PATH="../boost/" -DBoost_USE_STATIC_LIBS:BOOL="1" -DCMAKE_CXX_FLAGS_RELEASE:STRING="/MT /Zi /Ob0 /Od" -A x64 -G "Visual Studio 17"
msbuild /p:Configuration=Release /p:Platform=x64 src\ledger.vcxproj
copy Release\ledger.exe ..\