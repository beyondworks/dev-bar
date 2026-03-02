import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';

interface PermissionGuideProps {
  onGranted: () => void;
}

// Step data
const STEPS = [
  { n: 1, text: 'Open System Settings' },
  { n: 2, text: 'Privacy & Security → Accessibility' },
  { n: 3, text: 'Enable the toggle next to DevDock' },
];

export function PermissionGuide({ onGranted }: PermissionGuideProps) {
  const [checking, setChecking] = useState(false);
  const [pulse, setPulse] = useState(false);

  useEffect(() => {
    const interval = setInterval(async () => {
      setChecking(true);
      const status = await window.devdock.checkPermissions();
      setChecking(false);
      if (status.accessibility) {
        clearInterval(interval);
        onGranted();
      } else {
        // brief pulse to show it checked
        setPulse(true);
        setTimeout(() => setPulse(false), 600);
      }
    }, 2000);

    return () => clearInterval(interval);
  }, [onGranted]);

  return (
    <div style={styles.container}>
      <motion.div
        style={styles.card}
        initial={{ opacity: 0, scale: 0.94, y: 12 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ type: 'spring', stiffness: 360, damping: 28 }}
      >
        {/* Specular top edge */}
        <div style={styles.specularEdge} />

        {/* Icon row */}
        <div style={styles.iconWrap}>
          <motion.div
            style={styles.iconCircle}
            animate={{ boxShadow: pulse
              ? '0 0 0 8px rgba(0,122,255,0.12), 0 4px 20px rgba(0,122,255,0.35)'
              : '0 0 0 0px rgba(0,122,255,0.0), 0 4px 20px rgba(0,122,255,0.20)' }}
            transition={{ duration: 0.5 }}
          >
            {/* Lock icon - macOS Privacy & Security metaphor */}
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
              <rect
                x="4" y="11" width="16" height="11" rx="3"
                stroke="rgba(255,255,255,0.85)" strokeWidth="1.5"
              />
              <path
                d="M8 11V7.5a4 4 0 0 1 8 0V11"
                stroke="rgba(255,255,255,0.85)" strokeWidth="1.5" strokeLinecap="round"
              />
              <circle cx="12" cy="16.5" r="1.5" fill="rgba(255,255,255,0.85)" />
            </svg>
          </motion.div>
        </div>

        {/* Text */}
        <div style={styles.textBlock}>
          <h2 style={styles.title}>Accessibility Access Required</h2>
          <p style={styles.description}>
            DevDock needs Accessibility permission to detect and focus app windows.
            Your data stays entirely on your device.
          </p>
        </div>

        {/* Steps */}
        <div style={styles.stepsWrap}>
          {STEPS.map((step, i) => (
            <motion.div
              key={step.n}
              style={styles.stepRow}
              initial={{ opacity: 0, x: -8 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.08 + i * 0.06, type: 'spring', stiffness: 300, damping: 24 }}
            >
              <div style={styles.stepNum}>{step.n}</div>
              <span style={styles.stepText}>{step.text}</span>
            </motion.div>
          ))}
        </div>

        {/* CTA button */}
        <motion.button
          style={styles.button}
          onClick={() => window.devdock.openPermissionSettings()}
          whileHover={{ background: 'rgba(0,122,255,0.92)' }}
          whileTap={{ scale: 0.96 }}
          transition={{ duration: 0.12 }}
        >
          Open System Settings
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" style={{ marginLeft: 6 }}>
            <path d="M2.5 6h7M6.5 3l3 3-3 3" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </motion.button>

        {/* Auto-check status */}
        <div style={styles.pollingRow}>
          <motion.div
            style={styles.pollingDot}
            animate={{ opacity: checking ? [0.4, 1, 0.4] : 0.4 }}
            transition={{ duration: 1, repeat: checking ? Infinity : 0 }}
          />
          <span style={styles.pollingText}>
            {checking ? 'Checking permission…' : 'Waiting for permission grant…'}
          </span>
        </div>
      </motion.div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '100vw',
    height: '100vh',
    background: 'transparent',
  },
  card: {
    position: 'relative',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 0,
    width: 360,
    overflow: 'hidden',
    background:
      'linear-gradient(180deg, rgba(255,255,255,0.11) 0%, rgba(255,255,255,0.04) 60%, rgba(255,255,255,0.01) 100%), rgba(16,16,24,0.88)',
    backdropFilter: 'blur(64px) saturate(220%) brightness(1.06)',
    WebkitBackdropFilter: 'blur(64px) saturate(220%) brightness(1.06)',
    border: '0.5px solid rgba(255,255,255,0.22)',
    borderRadius: 22,
    boxShadow:
      '0 4px 20px rgba(0,0,0,0.28), 0 28px 80px rgba(0,0,0,0.42), inset 0 0.5px 0 rgba(255,255,255,0.30)',
    padding: '28px 26px 22px',
  },
  specularEdge: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    background:
      'linear-gradient(90deg, transparent 5%, rgba(255,255,255,0.32) 25%, rgba(255,255,255,0.32) 75%, transparent 95%)',
    borderRadius: '22px 22px 0 0',
    pointerEvents: 'none',
    zIndex: 2,
  },
  iconWrap: {
    marginBottom: 18,
  },
  iconCircle: {
    width: 64,
    height: 64,
    borderRadius: '50%',
    background:
      'linear-gradient(145deg, rgba(0,90,200,0.50), rgba(0,50,140,0.50))',
    border: '0.5px solid rgba(0,122,255,0.35)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    boxShadow: '0 4px 20px rgba(0,122,255,0.20)',
  },
  textBlock: {
    textAlign: 'center',
    marginBottom: 20,
    width: '100%',
  },
  title: {
    fontSize: 16,
    fontWeight: 650,
    color: 'rgba(255,255,255,0.95)',
    letterSpacing: '-0.025em',
    lineHeight: 1.25,
    marginBottom: 8,
  },
  description: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.50)',
    lineHeight: 1.65,
    letterSpacing: '-0.01em',
    padding: '0 4px',
  },
  stepsWrap: {
    width: '100%',
    background: 'rgba(255,255,255,0.05)',
    border: '0.5px solid rgba(255,255,255,0.10)',
    borderRadius: 12,
    padding: '4px 0',
    marginBottom: 18,
    display: 'flex',
    flexDirection: 'column',
  },
  stepRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '8px 12px',
  },
  stepNum: {
    width: 20,
    height: 20,
    borderRadius: '50%',
    background: 'rgba(0,122,255,0.22)',
    border: '0.5px solid rgba(0,122,255,0.35)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 10,
    fontWeight: 700,
    color: 'rgba(100,170,255,0.90)',
    flexShrink: 0,
    letterSpacing: 0,
  },
  stepText: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.68)',
    letterSpacing: '-0.01em',
    lineHeight: 1.4,
  },
  button: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
    padding: '10px 20px',
    background: 'rgba(0,122,255,0.80)',
    border: '0.5px solid rgba(0,122,255,0.45)',
    borderRadius: 12,
    color: 'rgba(255,255,255,0.96)',
    fontSize: 13,
    fontWeight: 600,
    cursor: 'pointer',
    letterSpacing: '-0.015em',
    boxShadow: '0 2px 10px rgba(0,122,255,0.30), inset 0 0.5px 0 rgba(255,255,255,0.22)',
    transition: 'background 0.12s',
    marginBottom: 14,
  },
  pollingRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
  },
  pollingDot: {
    width: 5,
    height: 5,
    borderRadius: '50%',
    background: 'rgba(52,199,89,0.70)',
    boxShadow: '0 0 4px rgba(52,199,89,0.40)',
    flexShrink: 0,
  },
  pollingText: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.28)',
    letterSpacing: '-0.01em',
  },
};
