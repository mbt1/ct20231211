import './App.css';
import React,{useState, useEffect} from 'react';
import { JupyterNotebookViewer } from "react-jupyter-notebook-viewer";
const bucket_url = 'https://ct20231211-reports.s3.amazonaws.com/'

function App() {
  const [files, setFiles] = useState([]);
  const [selectedFileURL, setSelectedFile] = useState('');

  useEffect(() => {
    const fetchFiles = async () => {
      try {
        const response = await fetch(bucket_url);
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
    const fileNames = Array.from(elements).map(element => element.textContent).sort((a,b)=>b.localeCompare(a));
    setFiles(fileNames);
    if (fileNames.length > 0) {
      setSelectedFile(bucket_url+fileNames[0]);
    }
  };

  const handleFileChange = (event) => {
    console.log(1, event.target.value)
    setSelectedFile(null);
    setTimeout(() => {
      setSelectedFile(event.target.value);
    }, 100)
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
        Select the report to display: 
        <select value={selectedFileURL} onChange={handleFileChange}>
          {files.map(file => (
            <option key={file} value={bucket_url+file}>{file}</option>
          ))}
        </select>
      </div>
        <DisplayNotebook notebook={selectedFileURL} />
    </div>
  );
}

function DisplayNotebook(props) {
  console.log(5, props.notebook)
  if(null==props.notebook){
    console.log(5,"is NULL")
    return <></>
  }
  console.log(5,"is not NULL")
  return (
    <>
      <div>
        <JupyterNotebookViewer 
            filePath={props.notebook} 
            outputDarkTheme="true"
            className = "NotebookViewer"
        />
      </div>
      <div>
        <span className='DownloadButton'>Download <a href={props.notebook}>{props.notebook.substring(bucket_url.length)}</a>.</span>
      </div>
    </>
  )

}
export default App;
