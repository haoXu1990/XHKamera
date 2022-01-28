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

    var cameraAdjustingExposureContext = "cameraAdjustingExposureContext"

    static let adjustingExposureKey = "adjustingExposure"

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

    override init() {
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

    /// @method 可用捕捉设备的数量
    /// @abstract
    ///   根据 AVMediaType 和 Position 返回可用捕捉设备的数量
    /// @param deviceTypes
    ///   媒体类型
    /// @param position
    ///   设备位置
    func cameraCount(mediaType: AVMediaType = .video, position: AVCaptureDevice.Position = .back) -> Int {
        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera],
                                                                     mediaType: .video,
                                                                     position: .back )
        return discoverySession.devices.count
    }


    func canSwitchCameras() -> Bool {
        return self.cameraCount() > 1
    }

    /// 根据位置获取摄像头设备
    func camera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {

        let discoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera],
                                                                     mediaType: .video,
                                                                     position: position)

        let device = discoverySession.devices.filter({ $0.position == position}).first
        return device
    }

    /// 获取当前活动的设备
    func activeCamera() -> AVCaptureDevice? {
        return self.activeVideoInput?.device
    }

    /// 返回当前未激活的摄像头
    func inactiveCamera() -> AVCaptureDevice? {
        if self.cameraCount() > 1 {
            if let activeCamera = activeCamera() {
                if activeCamera.position == .back {
                    return self.camera(position: .front)
                } else {
                    return self.camera(position: .back)
                }
            }
        }
        return nil
    }

    /// 切换摄像头
    func switchCameras() throws -> Bool {
        // 判断是否有多个摄像头
        if self.canSwitchCameras() == false || self.activeVideoInput == nil {
            return false
        }

        // 获取当前设备的反向设备
        if let videoDevice = self.inactiveCamera() {
            let videoInput = try AVCaptureDeviceInput.init(device: videoDevice)
            // 开始配置
            self.captureSession.beginConfiguration()

            // 将捕捉回话中，原来的捕捉输入设备移出
            self.captureSession.removeInput(self.activeVideoInput!)

            // 判断新的设备能否加入
            if self.captureSession.canAddInput(videoInput) {
                // 添加新设备
                self.captureSession.addInput(videoInput)

                // 修改当前的活动设备
                self.activeVideoInput = videoInput
            } else {
                // 新设备无法加入，把原来的设备重新加入到捕捉回话当中
                self.captureSession.addInput(self.activeVideoInput!)
            }

            // 提交配置
            self.captureSession.commitConfiguration()
        }

        return false
    }
}

extension XHCameraController {
    /// @method 当前活动的摄像头是否支持兴趣对焦(点击对焦)
    ///
    func cameraSuuportsTapToFocus() -> Bool {
        return self.activeCamera()?.isFocusPointOfInterestSupported ?? false
    }


    /// @method 兴趣对焦
    /// @abstract 根据 point 自动对焦
    /// @param point
    ///     兴趣对焦点
    func focusAtPoin(point: CGPoint) throws -> Void {
        guard let device = self.activeCamera() else { return }

        // 判断设备是否支持兴趣点对焦和自动对焦
        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {

            // 锁定设备准备开始配置， 如果获得了锁
            try device.lockForConfiguration()

            // 设置兴趣对焦的兴趣点
            device.focusPointOfInterest = point

            // 自动对焦模式
            device.focusMode = .autoFocus

            // 释放锁
            device.unlockForConfiguration()
        }
    }

    /// @method 当前活动的摄像头是否支持兴趣点击曝光
    func cameraSupportTapToExpose() -> Bool {
        return self.activeCamera()?.isExposurePointOfInterestSupported ?? false
    }

    func focusAtPoint(point: CGPoint) throws -> Void {
        guard let device = self.activeCamera() else { return }

        // 判断设备是否支持兴趣点曝光和自动曝光
        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {

            //  锁定设备
            try device.lockForConfiguration()

            // 配置曝光点和曝光模式
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose

            // 检查是否支持锁定曝光模式
            if device.isExposureModeSupported(.locked) {
                // 利用 KVO 确定设备的 adjustingExposure 属性的状态。
                // 这里利用 KOV 发送通知, 下面的方法接收通知后处理曝光锁定
                device.addObserver(self, forKeyPath: XHCameraController.adjustingExposureKey, options: .new, context:&cameraAdjustingExposureContext)
            }

            // 释放设备
            device.unlockForConfiguration()
        }
    }

    /// KOV 监听 adjustingExposure 更改摄像头曝光模式
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        // 判断上下文
        if context == &cameraAdjustingExposureContext {
            // 判断设备是否不再调整曝光等级, 确认设备的 exposureModel 是否可以设置为 locked
            if let device = object as? AVCaptureDevice,
               !device.isAdjustingExposure,
               device.isExposureModeSupported(.locked) {
                let objectClass = object as? XHCameraController
                // 移出监听
                objectClass?.removeObserver(self, forKeyPath: XHCameraController.adjustingExposureKey, context: &cameraAdjustingExposureContext)

                // 异步方式回到主队列
                DispatchQueue.main.async {

                    // 这里开始在主队列中修改设备
                    do {
                        // 锁定设备
                        try device.lockForConfiguration()

                        // 修改曝光模式
                        device.exposureMode = .locked

                        // 释放设备
                        device.unlockForConfiguration()

                    } catch _ {
                        // 这里应该抛出错误
                    }
                }
            }

        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    func resetFocusAndExposureModes() throws -> Void {
        guard let device = self.activeCamera() else { return }
        
        let canResetFocus = device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus)

        let canResetExposure = device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose)

        // 设备捕捉空间坐标,左上角(0, 0), 右下角(1, 1), 中心点(0.5, 0.5)
        let centPoint: CGPoint = .init(x: 0.5, y: 0.5)

        // 锁定设备
        try device.lockForConfiguration()

        // 检查是否支持兴趣点自动对焦
        if canResetFocus {
            device.focusMode = .autoFocus
            device.focusPointOfInterest = centPoint
        }

        // 检查是否支持兴趣点自动曝光
        if canResetExposure {
            device.exposureMode = .autoExpose
            device.exposurePointOfInterest = centPoint
        }

        // 释放设备
        device.unlockForConfiguration()
    }
}
