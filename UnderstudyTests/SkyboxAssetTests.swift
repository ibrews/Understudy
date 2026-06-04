//
//  SkyboxAssetTests.swift
//  UnderstudyTests
//
//  Verifies the bundled CC0 Poly Haven studio HDRI ships in the app bundle
//  and decodes via ImageIO on the visionOS target — i.e. the full-immersion
//  skybox gets the real photographic backdrop, not just the gradient
//  fallback. Hosted in the app (TEST_HOST), so Bundle.main is the Understudy
//  app bundle where the resource lives.
//

#if os(visionOS)
import Testing
import ImageIO
import Foundation

struct SkyboxAssetTests {

    @Test func studioHDRIBundledAndDecodes() throws {
        let url = try #require(
            Bundle.main.url(forResource: "studio_small_07_1k", withExtension: "exr"),
            "studio_small_07_1k.exr should ship in the app bundle"
        )
        let source = try #require(
            CGImageSourceCreateWithURL(url as CFURL, nil),
            "ImageIO should open the bundled .exr"
        )
        let image = try #require(
            CGImageSourceCreateImageAtIndex(source, 0, nil),
            "ImageIO should decode the OpenEXR HDRI to a CGImage on visionOS"
        )
        // Equirectangular 1K HDRI is 2:1.
        #expect(image.width == 1024)
        #expect(image.height == 512)
    }
}
#endif
