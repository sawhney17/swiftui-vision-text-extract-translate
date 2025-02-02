import SwiftUI
import Vision
import UIKit

// MARK: - OpenAI API Response Models

/// The structure for decoding the OpenAI API response.
struct OpenAIChatResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
}

// MARK: - Main ContentView

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var recognizedText: String = ""
    @State private var extractedKeywords: String = ""
    @State private var showImagePicker: Bool = false
    @State private var isLoadingKeywords: Bool = false
    @State private var isLoadingTranslation: Bool = false
    @State private var selectedLanguage = "English"
    @State private var extractedTranslation = ""
    let languages = ["English", "Spanish", "French", "German", "Chinese"]
    
    // Replace with your own API key.
    let openaiApiKey = "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"
    
    var body: some View {
        VStack(spacing: 20) {
            // Display the selected image or a placeholder.
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.secondary)
                    .frame(height: 300)
                    .overlay(Text("Tap to select an image").foregroundColor(.white))
                    .cornerRadius(8)
            }
            
            // Button to select an image.
            Button("Select Image") {
                showImagePicker = true
                showImagePicker = true
            }
            .font(.headline)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            // Button to extract text from the image.
            Button("Extract Text") {
                extractText(from: selectedImage)
            }
            .font(.headline)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(selectedImage == nil)
            
            // Show the recognized text.
            ScrollView {
                Text(recognizedText)
                    .padding()
            }
            .frame(maxHeight: 200)
            
            // Button to extract keywords from the recognized text.
            Button("Extract Keywords") {
                extractKeywords(from: recognizedText)
            }
            .font(.headline)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(recognizedText.isEmpty || isLoadingKeywords)
            
            // Show a loading indicator while waiting.
            if isLoadingKeywords {
                ProgressView("Extracting Keywords...")
            } else {
                ScrollView {
                    Text("Keywords:\n\(extractedKeywords)")
                        .padding()
                }
                .frame(maxHeight: 200)
            }
            VStack {
                Picker("Select Language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle()) // Makes it a dropdown menu
                .padding()
                
                Button(action: {
                    conductTranslation(from: extractedKeywords)
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Translate")
                    }
                }
                .font(.headline)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            // Show a loading indicator while waiting.
            if isLoadingTranslation {
                ProgressView("Determining Translation...")
            } else {
                ScrollView {
                    Text("\(extractedTranslation)")
                        .padding()
                }
                .frame(maxHeight: 200)
            }
            
        }
    }
    
    // MARK: - Text Recognition Using Vision
    
    /// Uses Vision to extract text from the provided UIImage.
    func extractText(from image: UIImage?) {
        guard let image = image, let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("Text recognition error: \(error.localizedDescription)")
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            var detectedText = ""
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    detectedText += candidate.string + "\n"
                }
            }
            DispatchQueue.main.async {
                recognizedText = detectedText
                // Clear previous keywords if any.
                extractedKeywords = ""
            }
        }
        
        // Adjust the recognition level as needed.
        request.recognitionLevel = .accurate
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform text recognition: \(error.localizedDescription)")
            }
        }
    }
    
   
    
    // MARK: - Extract Keywords via OpenAI API
    
    /// Sends the recognized text to the OpenAI API to extract keywords.
    
    /// Makes a request to the OpenAI chat completions API with the given prompt.
    /// - Parameters:
    ///   - prompt: The prompt/message you want to send.
    ///   - completion: A closure that will be called with the result string (if any).
    func queryOpenAI(with prompt: String, completion: @escaping (String?) -> Void) {
        // Make sure the prompt is not empty
        guard !prompt.isEmpty else {
            completion(nil)
            return
        }
        
        // Prepare the URL
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        // Create and configure the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // ⚠️ IMPORTANT: Replace with your own secure API key.
        request.addValue("Bearer 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", forHTTPHeaderField: "Authorization")
        
        // Prepare the payload – note that you can change the model, temperature, etc.
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("Error encoding payload: \(error)")
            completion(nil)
            return
        }
        
        // Perform the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("OpenAI API error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data returned from OpenAI API")
                completion(nil)
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                if let content = decoded.choices.first?.message.content {
                    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(trimmedContent)
                } else {
                    print("No content found in response")
                    completion(nil)
                }
            } catch {
                print("Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response string: \(responseString)")
                }
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - Example Usage
    
    /// Example function that uses `queryOpenAI` to extract keywords from a lab report text.
    func extractKeywords(from: String) {
        // Optionally update any UI state to show a loading indicator
        isLoadingKeywords = true
        
        // Build the prompt for this particular call
        let prompt = """
    Convert the lab report into a markdown table. You should format this in the form of 'measurement, measuredvalue, low, high'. Here is the \(from)
    """
        
        // Call the generic query function
        queryOpenAI(with: prompt) { result in
            // Always update UI on the main thread
            DispatchQueue.main.async {
//                let prompt2 = "take the value of the result and come up with a summary of the tools that they would need "
//                queryOpenAI(with: prompt2) { result in
                    // Always update UI on the main thread
                    DispatchQueue.main.async {
                        isLoadingKeywords = false
                        if let keywordText = result {
                            extractedKeywords = keywordText
                        } else {
                            print("Failed to extract keywords.")
                        }
//                    }
                }
            }
        }
    }
    func conductTranslation(from: String) {
        isLoadingTranslation = true
        
        let prompt = "translate \(from) this to \(selectedLanguage)"
        queryOpenAI(with: prompt) { result in
            // Always update UI on the main thread
            DispatchQueue.main.async {
                //                let prompt2 = "take the value of the result and come up with a summary of the tools that they would need "
                //                queryOpenAI(with: prompt2) { result in
                // Always update UI on the main thread
                DispatchQueue.main.async {
                    isLoadingTranslation = false
                    if let translationText = result {
                        extractedTranslation = translationText
                    } else {
                        print("Failed to extract keywords.")
                    }
                    //                    }
                }
            }
        }
        
    }
            
    
    // MARK: - Making Multiple Calls
    
}

// MARK: - UIKit Image Picker Wrapped for SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(parent: ImagePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates required.
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
