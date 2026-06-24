import React, { useRef, useEffect, useCallback, useState } from 'react'

const brushSizes = [2, 5, 10, 20, 30]
const colors = [
  '#ffffff', '#ff6b6b', '#feca57', '#48dbfb', '#1dd1a1',
  '#5f27cd', '#ff9ff3', '#54a0ff', '#00d2d3', '#222f3e',
]

export default function Canvas({ savedCanvas, onCanvasChange }) {
  const canvasRef = useRef(null)
  const contextRef = useRef(null)
  const [isDrawing, setIsDrawing] = useState(false)
  const [tool, setTool] = useState('brush')
  const [brushSize, setBrushSize] = useState(5)
  const [color, setColor] = useState('#ffffff')
  const [history, setHistory] = useState([])
  const [historyIndex, setHistoryIndex] = useState(-1)

  useEffect(() => {
    const canvas = canvasRef.current
    const container = canvas.parentElement
    canvas.width = container.clientWidth
    canvas.height = container.clientHeight

    const context = canvas.getContext('2d')
    context.fillStyle = '#0f0f23'
    context.fillRect(0, 0, canvas.width, canvas.height)
    context.lineCap = 'round'
    context.lineJoin = 'round'
    contextRef.current = context

    if (savedCanvas) {
      const img = new Image()
      img.onload = () => {
        context.drawImage(img, 0, 0)
        saveToHistory()
      }
      img.src = savedCanvas
    } else {
      saveToHistory()
    }

    const handleResize = () => {
      const imageData = canvas.toDataURL()
      canvas.width = container.clientWidth
      canvas.height = container.clientHeight
      context.fillStyle = '#0f0f23'
      context.fillRect(0, 0, canvas.width, canvas.height)
      const img = new Image()
      img.onload = () => context.drawImage(img, 0, 0)
      img.src = imageData
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  const saveToHistory = useCallback(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const imageData = canvas.toDataURL()
    setHistory(prev => [...prev.slice(0, historyIndex + 1), imageData])
    setHistoryIndex(prev => prev + 1)
    onCanvasChange?.(imageData)
  }, [historyIndex, onCanvasChange])

  const startDrawing = (e) => {
    const { offsetX, offsetY } = getCoordinates(e)
    contextRef.current.beginPath()
    contextRef.current.moveTo(offsetX, offsetY)
    setIsDrawing(true)
  }

  const draw = (e) => {
    if (!isDrawing) return
    const { offsetX, offsetY } = getCoordinates(e)

    if (tool === 'brush') {
      contextRef.current.strokeStyle = color
      contextRef.current.lineWidth = brushSize
    } else if (tool === 'eraser') {
      contextRef.current.strokeStyle = '#0f0f23'
      contextRef.current.lineWidth = brushSize * 2
    }

    contextRef.current.lineTo(offsetX, offsetY)
    contextRef.current.stroke()
  }

  const stopDrawing = () => {
    if (isDrawing) {
      contextRef.current.closePath()
      setIsDrawing(false)
      saveToHistory()
    }
  }

  const getCoordinates = (e) => {
    if (e.touches) {
      const rect = canvasRef.current.getBoundingClientRect()
      return {
        offsetX: e.touches[0].clientX - rect.left,
        offsetY: e.touches[0].clientY - rect.top,
      }
    }
    return { offsetX: e.nativeEvent.offsetX, offsetY: e.nativeEvent.offsetY }
  }

  const clearCanvas = () => {
    const context = contextRef.current
    context.fillStyle = '#0f0f23'
    context.fillRect(0, 0, canvasRef.current.width, canvasRef.current.height)
    saveToHistory()
  }

  const undo = () => {
    if (historyIndex > 0) {
      const newIndex = historyIndex - 1
      setHistoryIndex(newIndex)
      const img = new Image()
      img.onload = () => {
        const context = contextRef.current
        context.fillStyle = '#0f0f23'
        context.fillRect(0, 0, canvasRef.current.width, canvasRef.current.height)
        context.drawImage(img, 0, 0)
        onCanvasChange?.(history[newIndex])
      }
      img.src = history[newIndex]
    }
  }

  const redo = () => {
    if (historyIndex < history.length - 1) {
      const newIndex = historyIndex + 1
      setHistoryIndex(newIndex)
      const img = new Image()
      img.onload = () => {
        const context = contextRef.current
        context.fillStyle = '#0f0f23'
        context.fillRect(0, 0, canvasRef.current.width, canvasRef.current.height)
        context.drawImage(img, 0, 0)
        onCanvasChange?.(history[newIndex])
      }
      img.src = history[newIndex]
    }
  }

  return (
    <div className="canvas-container">
      <div className="toolbar">
        <div className="toolbar-section">
          <span className="toolbar-label">Tools</span>
          <div className="tool-buttons">
            <button
              className={`tool-btn ${tool === 'brush' ? 'active' : ''}`}
              onClick={() => setTool('brush')}
              title="Brush"
            >
              <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
                <path d="M7 14c-1.66 0-3 1.34-3 3 0 1.31-1.16 2-2 2 .92 1.22 2.49 2 4 2 2.21 0 4-1.79 4-4 0-1.66-1.34-3-3-3zm13.71-9.37l-1.34-1.34a.996.996 0 00-1.41 0L9 12.25 11.75 15l8.96-8.96a.996.996 0 000-1.41z"/>
              </svg>
            </button>
            <button
              className={`tool-btn ${tool === 'eraser' ? 'active' : ''}`}
              onClick={() => setTool('eraser')}
              title="Eraser"
            >
              <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
                <path d="M16.24 3.56l4.95 4.94c.78.79.78 2.05 0 2.84L12 20.53a4.008 4.008 0 01-5.66 0L2.81 17c-.78-.79-.78-2.05 0-2.84l10.27-10.27c.79-.78 2.05-.78 2.84 0zm-1.41 1.42L6.34 13.47l4.24 4.24 8.49-8.49-4.24-4.24z"/>
              </svg>
            </button>
          </div>
        </div>

        <div className="toolbar-section">
          <span className="toolbar-label">Size</span>
          <div className="size-buttons">
            {brushSizes.map(size => (
              <button
                key={size}
                className={`size-btn ${brushSize === size ? 'active' : ''}`}
                onClick={() => setBrushSize(size)}
              >
                <span style={{ width: size, height: size }} className="size-dot" />
              </button>
            ))}
          </div>
        </div>

        <div className="toolbar-section">
          <span className="toolbar-label">Color</span>
          <div className="color-buttons">
            {colors.map(c => (
              <button
                key={c}
                className={`color-btn ${color === c ? 'active' : ''}`}
                style={{ backgroundColor: c }}
                onClick={() => setColor(c)}
              />
            ))}
          </div>
        </div>

        <div className="toolbar-section actions">
          <button className="action-btn" onClick={undo} disabled={historyIndex <= 0} title="Undo">
            <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
              <path d="M12.5 8c-2.65 0-5.05.99-6.9 2.6L2 7v9h9l-3.62-3.62c1.39-1.16 3.16-1.88 5.12-1.88 3.54 0 6.55 2.31 7.6 5.5l2.37-.78C21.08 11.03 17.15 8 12.5 8z"/>
            </svg>
          </button>
          <button className="action-btn" onClick={redo} disabled={historyIndex >= history.length - 1} title="Redo">
            <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
              <path d="M18.4 10.6C16.55 8.99 14.15 8 11.5 8c-4.65 0-8.58 3.03-9.96 7.22L3.9 16c1.05-3.19 4.05-5.5 7.6-5.5 1.95 0 3.73.72 5.12 1.88L13 16h9V7l-3.6 3.6z"/>
            </svg>
          </button>
          <button className="action-btn clear" onClick={clearCanvas} title="Clear">
            <svg viewBox="0 0 24 24" fill="currentColor" width="20" height="20">
              <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/>
            </svg>
          </button>
        </div>
      </div>

      <div className="canvas-wrapper">
        <canvas
          ref={canvasRef}
          onMouseDown={startDrawing}
          onMouseMove={draw}
          onMouseUp={stopDrawing}
          onMouseLeave={stopDrawing}
          onTouchStart={startDrawing}
          onTouchMove={draw}
          onTouchEnd={stopDrawing}
        />
      </div>
    </div>
  )
}
