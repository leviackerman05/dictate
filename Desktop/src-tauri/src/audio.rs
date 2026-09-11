use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::sync::{mpsc, Arc, Mutex};
use tauri::Emitter;

pub struct Audio {
    tx: mpsc::Sender<Command>,
}
pub struct Recording {
    pub samples: Vec<f32>,
    pub rate: u32,
}
enum Command {
    Start(mpsc::Sender<Result<(), String>>),
    Stop(mpsc::Sender<Result<Recording, String>>),
    Cancel,
}
impl Audio {
    pub fn new(app: tauri::AppHandle) -> Self {
        let (tx, rx) = mpsc::channel();
        std::thread::spawn(move || {
            let mut stream: Option<cpal::Stream> = None;
            let samples = Arc::new(Mutex::new(Vec::new()));
            let failure = Arc::new(Mutex::new(None::<String>));
            let mut rate = 16000;
            while let Ok(cmd) = rx.recv() {
                match cmd {
                    Command::Start(reply) => {
                        stream.take();
                        samples.lock().unwrap().clear();
                        *failure.lock().unwrap() = None;
                        let result = (|| {
                            let device = cpal::default_host()
                                .default_input_device()
                                .ok_or("No microphone found. Connect one and try again.")?;
                            let config = device
                                .default_input_config()
                                .map_err(|e| format!("Microphone unavailable: {e}"))?;
                            rate = config.sample_rate().0;
                            let channels = config.channels() as usize;
                            let pcm = samples.clone();
                            let errors = failure.clone();
                            let handle = app.clone();
                            let error_fn = move |_e| {
                                *errors.lock().unwrap()=Some("Microphone disconnected or became unavailable. Reconnect it and retry.".into());
                            };
                            let mut meter = LevelMeter::new(rate);
                            let mut append = move |values: &[f32]| {
                                let mut output = pcm.lock().unwrap();
                                let cap = rate as usize * 60 * 10;
                                for frame in values.chunks(channels) {
                                    let value = frame.iter().sum::<f32>() / channels as f32;
                                    if let Some(level) = meter.push(value) {
                                        let _ = handle.emit("level", level);
                                    }
                                    if output.len() < cap {
                                        output.push(value);
                                    }
                                }
                            };
                            let audio=match config.sample_format() {
                                cpal::SampleFormat::F32=>device.build_input_stream(&config.into(),move |d:&[f32],_|append(d),error_fn,None),
                                cpal::SampleFormat::I16=>device.build_input_stream(&config.into(),move |d:&[i16],_|append(&d.iter().map(|x|*x as f32/32768.).collect::<Vec<_>>()),error_fn,None),
                                cpal::SampleFormat::U16=>device.build_input_stream(&config.into(),move |d:&[u16],_|append(&d.iter().map(|x|(*x as f32-32768.)/32768.).collect::<Vec<_>>()),error_fn,None),
                                _=>return Err("This microphone sample format is unsupported. Choose another system input.".into()),
                            }.map_err(|e|format!("Microphone access failed. Allow Dictate in your system microphone settings. {e}"))?;
                            audio.play().map_err(|e| e.to_string())?;
                            stream = Some(audio);
                            Ok(())
                        })();
                        let _ = reply.send(result);
                    }
                    Command::Stop(reply) => {
                        stream.take();
                        let values = std::mem::take(&mut *samples.lock().unwrap());
                        let result = if let Some(e) = failure.lock().unwrap().take() {
                            Err(e)
                        } else {
                            Ok(Recording {
                                samples: values,
                                rate,
                            })
                        };
                        let _ = reply.send(result);
                    }
                    Command::Cancel => {
                        stream.take();
                        samples.lock().unwrap().clear();
                    }
                }
            }
        });
        Self { tx }
    }
    pub fn start(&self) -> Result<(), String> {
        let (tx, rx) = mpsc::channel();
        self.tx
            .send(Command::Start(tx))
            .map_err(|e| e.to_string())?;
        rx.recv_timeout(std::time::Duration::from_secs(10))
            .map_err(|_| "Microphone startup timed out.".to_string())?
    }
    pub fn stop(&self) -> Result<Recording, String> {
        let (tx, rx) = mpsc::channel();
        self.tx.send(Command::Stop(tx)).map_err(|e| e.to_string())?;
        rx.recv_timeout(std::time::Duration::from_secs(10))
            .map_err(|_| "Microphone stop timed out.".to_string())?
    }
    pub fn cancel(&self) {
        let _ = self.tx.send(Command::Cancel);
    }
}

// Accumulate energy and frame count over the same 1/30-second window,
// independently of the device's callback buffer size. Emits raw RMS.
struct LevelMeter {
    energy: f64,
    frames: usize,
    window: usize,
}
impl LevelMeter {
    fn new(rate: u32) -> Self {
        Self {
            energy: 0.0,
            frames: 0,
            window: (rate as usize / 30).max(1),
        }
    }
    fn push(&mut self, sample: f32) -> Option<f32> {
        let sample = if sample.is_finite() { sample } else { 0.0 };
        self.energy += (sample as f64).powi(2);
        self.frames += 1;
        if self.frames < self.window {
            return None;
        }
        let rms = (self.energy / self.frames as f64).sqrt() as f32;
        self.energy = 0.0;
        self.frames = 0;
        Some(rms.clamp(0.0, 1.0))
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn meter_is_callback_independent_and_thirty_hz() {
        for rate in [16000, 44100, 48000] {
            let mut meter = LevelMeter::new(rate);
            let levels: Vec<_> = (0..rate).filter_map(|_| meter.push(0.125)).collect();
            assert_eq!(levels.len(), 30);
            assert!(levels.iter().all(|v| (*v - 0.125).abs() < 0.0001));
            let silent: Vec<_> = (0..rate).filter_map(|_| meter.push(0.0)).collect();
            assert_eq!(*silent.last().unwrap(), 0.0);
        }
    }
}
