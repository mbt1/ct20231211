import './App.css';
import React,{useState, useEffect} from 'react';
import ViewNotebook from 'react-jupyter-notebook';

const bucket_url = 'https://ct20231211-reports.s3.amazonaws.com/'

function App() {
  const [files, setFiles] = useState([]);
  const [selectedFileURL, setSelectedFile] = useState('');
  const [notebookContent, setNotebookContent] = useState(null);

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
    setSelectedFile(event.target.value);
  };

  useEffect(() => {
    const fetchNotebook = async (NotebookURL) => {
      try {
        console.log(3, NotebookURL)
        const response = await fetch(NotebookURL);
        const data = await response.json();
        console.log(4,data)
        setNotebookContent(data);
      } catch (error) {
        console.error("Error fetching notebook: ", error);
        setNotebookContent(null);
      }
    };
    console.log(2,selectedFileURL)
    if(null != selectedFileURL){
      fetchNotebook(selectedFileURL);
    }
  }, [selectedFileURL]);

  return (
    <div className="App">
      <header className="App-header">
        <h1>
          <img src={`${process.env.PUBLIC_URL}/logo192.png`} className="App-logo" alt="logo" />
          A simple .ipynb report viewer
        </h1>
      </header>
      <div>
        <select value={selectedFileURL} onChange={handleFileChange}>
          {files.map(file => (
            <option key={file} value={bucket_url+file}>{file}</option>
          ))}
        </select>
        {!(null==notebookContent) &&<ViewNotebook notebook={notebookContent} />}
      </div>
    </div>
  );
}

// function DisplayNotebook(props) {
//   console.log(5, props.json)
//   if(null==props.json){
//     console.log(5,"is NULL")
//     return <></>
//   }
//   console.log(5,"is not NULL")
//   return <><ViewNotebook notebook={props.json} /></>
// }
export default App;
