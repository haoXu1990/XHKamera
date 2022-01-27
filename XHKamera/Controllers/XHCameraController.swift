//
//  XHCameraController.swift
//  XHKamera
//
//  Created by XuHao on 2022/1/27.
//

import Foundation
import AVFoundation
import UIKit

protocol XHCameraControllerDelegate {
    /// 发生设备错误
    func deviceConfigurationFailedWithError(error: NSError)

    func mediaCapttureFailedWithError(error: NSError)

    func assetLibraryWriteFailedWithError(error: NSError)
}


class XHCameraController: NSObject {

    /// 视频队列
    let videoQueue = DispatchQueue.init(label: "xh.VideoQueue")

    /// 捕捉回话
    var captureSession: AVCaptureSession!

    /// 当前活动的输入设备
    var activeVideoInput: AVCaptureDeviceInput?

    /// 图片输出
    var imageOutput: AVCapturePhotoOutput!

    /// 视频输出
    var movieOutput: AVCaptureMovieFileOutput!

    var outputURL: NSURL?

    init(error: NSError) {
        super.init()
    }

    func setupSession() throws -> Bool {

        // 1. 创建一个捕捉回话， AVCaptureSession 是捕捉场景的中心枢纽
        self.captureSession = AVCaptureSession.init()

        // 1.1 设置初始图像分辨率
        self.captureSession.sessionPreset = .high

        // 1.2 拿到默认的视频捕捉设备
        let videoDevice = AVCaptureDevice.default(for: .video)
        guard let videoDevice = videoDevice else { return false }

        // 1.3 将视频设备转换成 输入设备[AVCaptureDeviceInput]
        let videoInput = try AVCaptureDeviceInput.init(device: videoDevice)

        // 判断是否能将输入设备添加到回话中
        if self.captureSession.canAddInput(videoInput) {
            // 添加设备
            self.captureSession.addInput(videoInput)
            self.activeVideoInput = videoInput
        } else {
            return false
        }

        // 1.4 创建音频捕捉设备
        // 1.4.1 拿到设备默认的音频设备
        let audioDevice = AVCaptureDevice.default(for: .audio)
        guard let audioDevice = audioDevice else { return false }
        // 1.4.2 把音频设备转换成 输入设备
        let audioInput = try AVCaptureDeviceInput.init(device: audioDevice)

        if self.captureSession.canAddInput(audioInput) {
            self.captureSession.addInput(audioInput)
        }

        // 2. 设置图片输出设备
        self.imageOutput = AVCapturePhotoOutput.init()

        // 2.1 设置捕获格式
        let formatDic = [AVVideoCodecKey: AVVideoCodecType.jpeg]
        let photoSettting = AVCapturePhotoSettings.init(format: formatDic)
        self.imageOutput.photoSettingsForSceneMonitoring = photoSettting

        // 2.2 加入图片输出设备到 AVCaptureSession
        if self.captureSession.canAddOutput(self.imageOutput) {
            self.captureSession.addOutput(self.imageOutput)
        }

        // 3. 设置 Video 输出设备
        self.movieOutput = AVCaptureMovieFileOutput.init()
        if self.captureSession.canAddOutput(self.movieOutput) {
            self.captureSession.addOutput(self.movieOutput)
        }

        return true
    }
}

extension XHCameraController {
    /// 启动 Session
    func startSession() {
        if self.captureSession.isRunning == false {
            // 使用异步串行队列执行任务
            self.videoQueue.async {
                self.captureSession.startRunning()
            }
        }
    }

    /// 停止 Session
    func stopSession() {
        if self.captureSession.isRunning == false {
            self.videoQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }
}

// Mark: - 摄像头支持的一些方法
extension XHCameraController {

    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {

        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera],
                                                                     mediaType: .video,
                                                                     position: position)

        return discoverySession.devices.first
    }

    func activeCamera() -> AVCaptureDevice? {
        return self.activeVideoInput?.device
    }
}
