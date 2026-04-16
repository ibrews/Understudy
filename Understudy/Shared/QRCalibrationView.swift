//
//  QRCalibrationView.swift
//  Understudy
//
//  Shows the fixed calibration QR target at a known physical size so the
//  director can print or display it and performers can scan it with their
//  iPhones for precise shared-origin calibration.
//
//  Two usage patterns:
//    - iPhone / iPad: opens as a sheet from Settings → "Show QR for
//      performers to scan"; dim-background full-screen display.
//    - visionOS: opens as a window the director can place on a wall or
//      floor. Performers walk up and point their phones.
//
//  The image is regenerated every time the view appears; it's not cached
//  because it's cheap (CoreImage + a single filter invocation).
//

#if canImport(UIKit)
import SwiftUI
import UIKit

struct QRCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    #if os(iOS)
    @State private var previousBrightness: CGFloat = 0.5
    #endif

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 20) {
                header
                qrDisplay
                footer
            }
            .padding(24)
        }
        .preferredColorScheme(.light)
        .onAppear {
            qrImage = QRCalibration.generateQR(
                payload: "understudy://calibrate",
                pixelSize: 1024
            )
            #if os(iOS)
            // Ramp screen brightness to max — QR detection is much faster
            // against a bright screen.
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
            #endif
        }
        .onDisappear {
            #if os(iOS)
            UIScreen.main.brightness = previousBrightness
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Understudy Calibration Target")
                .font(.headline)
                .foregroundStyle(.black)
            Text("Display at \(Int(QRCalibration.defaultPhysicalSizeM * 1000)) mm wide · print edge-to-edge")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var qrDisplay: some View {
        ZStack {
            if let image = qrImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: 480)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Performers: open Understudy, point your camera at this target. Calibration is automatic.")
                .font(.footnote)
                .foregroundStyle(.black.opacity(0.75))
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }
}
#endif
