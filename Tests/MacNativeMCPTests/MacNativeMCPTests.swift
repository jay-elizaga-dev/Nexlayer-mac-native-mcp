import XCTest
@testable import MacNativeMCP

final class MacNativeMCPTests: XCTestCase {

    // MARK: - extractSlug

    func testExtractSlug_singleToken() {
        XCTAssertEqual(NexlayerService.extractSlug(from: "myapp-service"), "myapp")
    }

    func testExtractSlug_nilWhenNoServiceSuffix() {
        XCTAssertNil(NexlayerService.extractSlug(from: "myapp-web"))
    }

    func testExtractSlug_slugRepeatDetected() {
        XCTAssertEqual(NexlayerService.extractSlug(from: "foo-foo-service"), "foo")
    }

    func testExtractSlug_multiTokenSlugRepeatDetected() {
        XCTAssertEqual(NexlayerService.extractSlug(from: "myapp-web-myapp-web-service"), "myapp-web")
    }

    func testExtractSlug_infraSuffixStripped() {
        XCTAssertEqual(NexlayerService.extractSlug(from: "myapp-web-service"), "myapp")
    }

    func testExtractSlug_minioInfraSuffixStripped() {
        XCTAssertEqual(NexlayerService.extractSlug(from: "storage-minio-service"), "storage")
    }

    func testExtractSlug_noPatternReturnsFullName() {
        XCTAssertEqual(NexlayerService.extractSlug(from: "foo-bar-service"), "foo-bar")
    }

    // MARK: - parseDeploymentSlugs

    func testParseDeploymentSlugs_normalBlock() {
        let text = """
        SERVICES:
          foo-foo-service
          bar-web-service
        CONFIGMAPS:
        """
        XCTAssertEqual(NexlayerService.parseDeploymentSlugs(from: text), ["bar", "foo"])
    }

    func testParseDeploymentSlugs_emptyBlock() {
        let text = """
        SERVICES:
        CONFIGMAPS:
        """
        XCTAssertEqual(NexlayerService.parseDeploymentSlugs(from: text), [])
    }

    func testParseDeploymentSlugs_systemServicesFiltered() {
        let text = """
        SERVICES:
          nexlayer-debug-proxy
          pod
          myapp-myapp-service
        CONFIGMAPS:
        """
        XCTAssertEqual(NexlayerService.parseDeploymentSlugs(from: text), ["myapp"])
    }

    func testParseDeploymentSlugs_deduplicatesSlugs() {
        let text = """
        SERVICES:
          myapp-myapp-service
          myapp-web-service
        CONFIGMAPS:
        """
        XCTAssertEqual(NexlayerService.parseDeploymentSlugs(from: text), ["myapp"])
    }
}
