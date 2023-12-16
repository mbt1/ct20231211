import './App.css';
import React,{useState, useEffect} from 'react';

function App() {
  const [files, setFiles] = useState([]);

  useEffect(() => {
    const fetchFiles = async () => {
      try {
        const response = await fetch('https://ct20231211-reports.s3.amazonaws.com/');
        const data = await response.text();
        parseXML(data);
      } catch (error) {
        console.error("Error fetching file list: ", error);
      }
    };
  
    fetchFiles();
  }, []);
  
  const parseXML = (xmlData) => {
    const parser = new DOMParser();
    const xml = parser.parseFromString(xmlData, "application/xml");
    const elements = xml.getElementsByTagName("Key");
    const fileNames = Array.from(elements).map(element => element.textContent);
    setFiles(fileNames);
  };
  
  return (
    <div className="App">
      <header className="App-header">
        <h1>
          <img src={`${process.env.PUBLIC_URL}/logo192.png`} className="App-logo" alt="logo" />
          A simple .ipynb report viewer
        </h1>
      </header>
      <div>
        <select>
          {files.map(file => (
            <option key={file} value={file}>{file}</option>
          ))}
        </select>
      </div>
    </div>
  );
}

export default App;
