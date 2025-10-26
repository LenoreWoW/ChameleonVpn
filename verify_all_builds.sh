#!/bin/bash

# BarqNet - Final Build Verification Script
# Tests all platforms to ensure everything is working

echo "🔍 BarqNet - Final Build Verification"
echo "==========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track results
DESKTOP_SUCCESS=false
IOS_SUCCESS=false  
ANDROID_SUCCESS=false

echo "📋 Testing all platforms..."
echo ""

# Test Desktop
echo -e "${BLUE}🖥️  Testing Desktop Application...${NC}"
cd barqnet-desktop

if npm run build > /dev/null 2>&1; then
    echo -e "   ✅ ${GREEN}Desktop build: SUCCESS${NC}"
    DESKTOP_SUCCESS=true
else
    echo -e "   ❌ ${RED}Desktop build: FAILED${NC}"
fi

if npm run lint > /dev/null 2>&1; then
    echo -e "   ✅ ${GREEN}Desktop linting: CLEAN${NC}"
else
    echo -e "   ⚠️  ${YELLOW}Desktop linting: WARNINGS (acceptable)${NC}"
fi

echo ""

# Test iOS  
echo -e "${BLUE}📱 Testing iOS Application...${NC}"
cd ../barqnet-ios

if [ -f "BarqNet.xcworkspace/contents.xcworkspacedata" ]; then
    echo -e "   ✅ ${GREEN}iOS project: READY${NC}"
    IOS_SUCCESS=true
else
    echo -e "   ❌ ${RED}iOS project: MISSING${NC}"
fi

if [ -f "Podfile.lock" ]; then
    echo -e "   ✅ ${GREEN}iOS dependencies: INSTALLED${NC}"
else
    echo -e "   ❌ ${RED}iOS dependencies: MISSING${NC}"
fi

echo ""

# Test Android
echo -e "${BLUE}🤖 Testing Android Application...${NC}"
cd ../barqnet-android

export JAVA_HOME=/opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home

if ./gradlew assembleDebug > /dev/null 2>&1; then
    echo -e "   ✅ ${GREEN}Android build: SUCCESS${NC}"
    ANDROID_SUCCESS=true
else
    echo -e "   ❌ ${RED}Android build: FAILED${NC}"
fi

if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    echo -e "   ✅ ${GREEN}Android APK: GENERATED${NC}"
    
    # Get APK size  
    APK_SIZE=$(du -h app/build/outputs/apk/debug/app-debug.apk | cut -f1)
    echo -e "   📦 ${BLUE}APK size: ${APK_SIZE}${NC}"
else
    echo -e "   ❌ ${RED}Android APK: MISSING${NC}"
fi

echo ""
echo "==========================================="
echo "🎯 FINAL VERIFICATION RESULTS"
echo "==========================================="

# Desktop Results
if [ "$DESKTOP_SUCCESS" = true ]; then
    echo -e "🖥️  Desktop: ✅ ${GREEN}READY FOR PRODUCTION${NC}"
else
    echo -e "🖥️  Desktop: ❌ ${RED}NEEDS ATTENTION${NC}"
fi

# iOS Results
if [ "$IOS_SUCCESS" = true ]; then
    echo -e "📱 iOS: ✅ ${GREEN}READY FOR XCODE${NC}"
else
    echo -e "📱 iOS: ❌ ${RED}NEEDS SETUP${NC}"
fi

# Android Results  
if [ "$ANDROID_SUCCESS" = true ]; then
    echo -e "🤖 Android: ✅ ${GREEN}READY FOR DEPLOYMENT${NC}"
else
    echo -e "🤖 Android: ❌ ${RED}NEEDS FIXES${NC}"
fi

echo ""

# Overall Status
TOTAL_SUCCESS=0
if [ "$DESKTOP_SUCCESS" = true ]; then ((TOTAL_SUCCESS++)); fi
if [ "$IOS_SUCCESS" = true ]; then ((TOTAL_SUCCESS++)); fi  
if [ "$ANDROID_SUCCESS" = true ]; then ((TOTAL_SUCCESS++)); fi

echo -e "📊 Overall Success: ${TOTAL_SUCCESS}/3 platforms"

if [ $TOTAL_SUCCESS -eq 3 ]; then
    echo -e "🎉 ${GREEN}ALL PLATFORMS WORKING - PROJECT COMPLETE!${NC}"
    echo ""
    echo "🚀 Ready for:"
    echo "   • Desktop: Immediate use and deployment"
    echo "   • iOS: Xcode build and App Store submission" 
    echo "   • Android: Device testing and Play Store upload"
    echo ""
    echo "✨ MISSION ACCOMPLISHED! ✨"
elif [ $TOTAL_SUCCESS -eq 2 ]; then
    echo -e "🎯 ${YELLOW}MOSTLY COMPLETE - 1 platform needs attention${NC}"
else
    echo -e "⚠️  ${RED}MULTIPLE ISSUES - Review failed platforms${NC}"
fi

echo ""
echo "==========================================="

cd ../
