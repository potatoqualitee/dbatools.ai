-- Table 1: Pet
CREATE TABLE Pet (
    pet_id INT PRIMARY KEY IDENTITY(1,1),  -- Primary key for the pet
    pet_name VARCHAR(100) NOT NULL,
    owner_name VARCHAR(100) NOT NULL,
    pet_breed VARCHAR(100) NOT NULL
);

-- Table 2: Vaccination
CREATE TABLE Vaccination (
    vaccination_id INT PRIMARY KEY IDENTITY(1,1),  -- Primary key for the vaccination
    pet_id INT NOT NULL,  -- Foreign key referencing Pet table
    vaccine_name VARCHAR(100) NOT NULL,
    date_administered_1 DATE NOT NULL,
    date_administered_2 DATE NULL,
    date_administered_3 DATE NULL,
    veterinarian VARCHAR(100) NOT NULL,
    CONSTRAINT FK_Pet_Vaccination FOREIGN KEY (pet_id) REFERENCES Pet(pet_id)  -- Foreign key constraint
);
