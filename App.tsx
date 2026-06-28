import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  StyleSheet,
  Text,
  View,
  Pressable,
  ScrollView,
  Platform,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import AsyncStorage from '@react-native-async-storage/async-storage';

const MONO = Platform.OS === 'ios' ? 'Menlo' : 'monospace';
const STORAGE_KEY_BALANCE = '@bank_balance';
const STORAGE_KEY_LOG = '@bank_log';
const STORAGE_KEY_DAILY_FOCUS = '@bank_daily_focus';

type Session = {
  date: string;
  duration: string;
  earned: number;
};

function formatTime(totalSeconds: number): string {
  const m = Math.floor(totalSeconds / 60);
  const s = totalSeconds % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function todayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export default function App() {
  const [balance, setBalance] = useState(0);
  const [dailyFocusSeconds, setDailyFocusSeconds] = useState(0);
  const [log, setLog] = useState<Session[]>([]);
  const [loaded, setLoaded] = useState(false);

  const [focusRunning, setFocusRunning] = useState(false);
  const [focusElapsed, setFocusElapsed] = useState(0);
  const focusInterval = useRef<ReturnType<typeof setInterval> | null>(null);

  const [scrolling, setScrolling] = useState(false);
  const scrollInterval = useRef<ReturnType<typeof setInterval> | null>(null);

  const [showLog, setShowLog] = useState(false);

  const unlocked = dailyFocusSeconds >= 900;
  const secondsToUnlock = Math.max(0, 900 - dailyFocusSeconds);

  useEffect(() => {
    (async () => {
      try {
        const [bStr, lStr, dfStr] = await Promise.all([
          AsyncStorage.getItem(STORAGE_KEY_BALANCE),
          AsyncStorage.getItem(STORAGE_KEY_LOG),
          AsyncStorage.getItem(STORAGE_KEY_DAILY_FOCUS),
        ]);
        if (bStr !== null) setBalance(parseInt(bStr, 10));
        if (lStr !== null) setLog(JSON.parse(lStr));
        if (dfStr !== null) {
          const parsed = JSON.parse(dfStr);
          if (parsed.date === todayKey()) {
            setDailyFocusSeconds(parsed.seconds);
          }
        }
      } catch {}
      setLoaded(true);
    })();
  }, []);

  const persist = useCallback(async (b: number, l: Session[], dfs: number) => {
    try {
      await Promise.all([
        AsyncStorage.setItem(STORAGE_KEY_BALANCE, String(b)),
        AsyncStorage.setItem(STORAGE_KEY_LOG, JSON.stringify(l)),
        AsyncStorage.setItem(STORAGE_KEY_DAILY_FOCUS, JSON.stringify({ date: todayKey(), seconds: dfs })),
      ]);
    } catch {}
  }, []);

  useEffect(() => {
    if (focusRunning) {
      focusInterval.current = setInterval(() => {
        setFocusElapsed((e) => e + 1);
      }, 1000);
    } else if (focusInterval.current) {
      clearInterval(focusInterval.current);
      focusInterval.current = null;
    }
    return () => {
      if (focusInterval.current) clearInterval(focusInterval.current);
    };
  }, [focusRunning]);

  useEffect(() => {
    if (scrolling) {
      scrollInterval.current = setInterval(() => {
        setBalance((b) => {
          if (b <= 0) {
            setScrolling(false);
            return 0;
          }
          const newB = b - 1;
          AsyncStorage.setItem(STORAGE_KEY_BALANCE, String(newB)).catch(() => {});
          return newB;
        });
      }, 1000);
    } else if (scrollInterval.current) {
      clearInterval(scrollInterval.current);
      scrollInterval.current = null;
    }
    return () => {
      if (scrollInterval.current) clearInterval(scrollInterval.current);
    };
  }, [scrolling]);

  const handleFocusToggle = () => {
    if (focusRunning) {
      setFocusRunning(false);
      const earned = Math.floor(focusElapsed / 60);
      if (earned > 0) {
        const newDfs = dailyFocusSeconds + focusElapsed;
        const newBalance = balance + earned;
        const session: Session = {
          date: new Date().toLocaleDateString(),
          duration: formatTime(focusElapsed),
          earned,
        };
        const newLog = [session, ...log];
        setBalance(newBalance);
        setDailyFocusSeconds(newDfs);
        setLog(newLog);
        persist(newBalance, newLog, newDfs);
      } else {
        const newDfs = dailyFocusSeconds + focusElapsed;
        setDailyFocusSeconds(newDfs);
        persist(balance, log, newDfs);
      }
      setFocusElapsed(0);
    } else {
      setFocusRunning(true);
    }
  };

  const handleScrollToggle = () => {
    if (scrolling) {
      setScrolling(false);
    } else if (balance > 0) {
      setScrolling(true);
    }
  };

  if (!loaded) return <View style={styles.container} />;

  return (
    <View style={styles.container}>
      <StatusBar style="light" />

      {/* Bank Balance */}
      <View style={styles.section}>
        <Text style={styles.bigNumber}>{formatTime(balance * 60)}</Text>
        {!unlocked ? (
          <Text style={styles.sublabel}>
            {formatTime(secondsToUnlock)} to first unlock
          </Text>
        ) : balance <= 0 && !scrolling ? (
          <Text style={styles.sublabel}>Bank empty</Text>
        ) : (
          <Pressable
            style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
            onPress={handleScrollToggle}
          >
            <Text style={styles.buttonText}>
              {scrolling ? 'Stop Scrolling' : 'Start Scrolling'}
            </Text>
          </Pressable>
        )}
      </View>

      {/* Focus Timer */}
      <View style={styles.section}>
        <Text style={styles.bigNumber}>{formatTime(focusElapsed)}</Text>
        <Pressable
          style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
          onPress={handleFocusToggle}
        >
          <Text style={styles.buttonText}>
            {focusRunning ? 'Stop' : 'Start'}
          </Text>
        </Pressable>
      </View>

      {/* Log Button */}
      <Pressable
        style={({ pressed }) => [styles.logButton, pressed && styles.buttonPressed]}
        onPress={() => setShowLog(true)}
      >
        <Text style={styles.logButtonText}>Show Log</Text>
      </Pressable>

      {/* Log Overlay */}
      {showLog && (
        <View style={styles.modalOverlay}>
          <Pressable style={styles.modalBackdrop} onPress={() => setShowLog(false)} />
          <View style={styles.modalContent}>
            <ScrollView>
              {log.length === 0 ? (
                <Text style={[styles.logText, { textAlign: 'center', marginTop: 40 }]}>
                  No sessions yet
                </Text>
              ) : (
                log.map((item, i) => (
                  <View key={i} style={styles.logRow}>
                    <Text style={styles.logText}>{item.date}</Text>
                    <Text style={styles.logText}>{item.duration}</Text>
                    <Text style={styles.logText}>+{item.earned}m</Text>
                  </View>
                ))
              )}
            </ScrollView>
            <Pressable
              style={({ pressed }) => [styles.button, { marginTop: 16, alignSelf: 'center' }, pressed && styles.buttonPressed]}
              onPress={() => setShowLog(false)}
            >
              <Text style={styles.buttonText}>Close</Text>
            </Pressable>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    paddingTop: 80,
    paddingBottom: 60,
    paddingHorizontal: 32,
    justifyContent: 'space-between',
  },
  section: {
    alignItems: 'center',
    gap: 20,
  },
  bigNumber: {
    fontFamily: MONO,
    fontSize: 64,
    color: '#fff',
    letterSpacing: 4,
  },
  sublabel: {
    fontFamily: MONO,
    fontSize: 14,
    color: '#666',
  },
  button: {
    paddingVertical: 14,
    paddingHorizontal: 32,
    borderWidth: 1,
    borderColor: '#333',
    borderRadius: 4,
  },
  buttonPressed: {
    backgroundColor: '#111',
  },
  buttonText: {
    fontFamily: MONO,
    fontSize: 16,
    color: '#fff',
  },
  logButton: {
    alignSelf: 'center',
    paddingVertical: 14,
  },
  logButtonText: {
    fontFamily: MONO,
    fontSize: 14,
    color: '#666',
  },
  modalOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'flex-end',
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.8)',
  },
  modalContent: {
    backgroundColor: '#111',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    padding: 24,
    maxHeight: '70%',
    minHeight: '40%',
  },
  logRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#222',
  },
  logText: {
    fontFamily: MONO,
    fontSize: 14,
    color: '#888',
  },
});
