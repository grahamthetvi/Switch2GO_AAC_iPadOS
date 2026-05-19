import { Component, type ErrorInfo, type ReactNode } from 'react'

interface Props {
  children: ReactNode
  onError?: (message: string) => void
  fallback?: ReactNode
}

interface State {
  hasError: boolean
  message: string | null
}

/** Catches render errors in the tracking UI subtree (e.g. worker/WASM edge cases). */
export class TrackingErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, message: null }

  static getDerivedStateFromError(error: Error): State {
    return {
      hasError: true,
      message: error.message || 'Tracking failed unexpectedly',
    }
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    const message = error.message || 'Tracking failed unexpectedly'
    this.props.onError?.(message)
    console.error('TrackingErrorBoundary:', error, info.componentStack)
  }

  render(): ReactNode {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback
      return null
    }
    return this.props.children
  }
}
