# Dictate benchmark

Generated: 2026-09-08T15:29:53Z

- Hardware: Mac14,2 (arm64)
- Processor: Apple M2
- Memory: 17179869184 bytes
- OS: Version 26.5.2 (Build 25F84)
- Audio: `synthetic.wav`
- Audio duration: 3.7949 seconds
- Reference supplied: yes

| Engine | Model | Status | Transcription (s) | RTF | WER |
| --- | --- | --- | ---: | ---: | ---: |
| apple | apple | completed | 0.4009 | 0.1056 | 0.0000 |

## Apple SpeechAnalyzer

Insertion-independent transcription output:

```text
This is a local dictation test. Keep my words on this computer.
```

## CI-built release artifact

The DMG produced by release run `34244906682` was downloaded, mounted read-only, and its strict ad-hoc signature and build 11004 verified. The executable inside that DMG completed the same Apple test in **0.2992 seconds**, RTF **0.0789**, normalized WER **0** on the same host. This validates the distributed binary as well as the local build. No microphone or model download was involved.
