# Mulberry Blast

Dark-mulberry block puzzle for iPhone (SwiftUI, iOS 16+). Needs a Mac with Xcode 15+.

## Option A: XcodeGen (fastest)
    brew install xcodegen
    xcodegen generate
    open MulberryBlast.xcodeproj
Pick your iPhone or a simulator, set your Team under Signing & Capabilities, press Run.

## Option B: Manual
1. Xcode > File > New > Project > iOS App (SwiftUI), name it MulberryBlast.
2. Delete the generated ContentView.swift and App file.
3. Drag the four .swift files from MulberryBlast/ into the project.
4. Run.

## Making the IPA
Product > Archive > Distribute App (Ad Hoc / Development), or use your sideloading tool of choice on the archived .app.

## Rules
8x8 grid, drag one of three pieces onto it. Full rows/columns clear. Consecutive clears build a combo. Clearing the whole board is a Perfect Clear (+200). Daily mode gives everyone the same pieces and starting blocks each date. Game ends when no piece fits.
