/** Request camera permission during a user gesture (required on iOS Safari). */
export async function requestCameraAccess(): Promise<void> {
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error('Camera not supported in this browser')
  }
  const stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
    audio: false,
  })
  stream.getTracks().forEach((track) => track.stop())
}
