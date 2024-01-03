-- A/ Création du schéma de la base de données

Drop Table Utilisateur CASCADE CONSTRAINTS;
Drop Table Achatgroupe CASCADE CONSTRAINTS;
Drop Table Achatutilisateur CASCADE CONSTRAINTS;
Drop Table Appartient CASCADE CONSTRAINTS;
Drop Table Employé CASCADE CONSTRAINTS;
Drop Table Groupe CASCADE CONSTRAINTS;
Drop Table Gère CASCADE CONSTRAINTS;
Drop Table Inclue CASCADE CONSTRAINTS;
Drop Table Licence CASCADE CONSTRAINTS;
Drop Table Logiciel CASCADE CONSTRAINTS;
Drop Table Modifie CASCADE CONSTRAINTS;
Drop Table Ticket CASCADE CONSTRAINTS;

CREATE TABLE Utilisateur (
    id_utilisateur NUMBER(10) NOT NULL,
    Nom VARCHAR2(30) NOT NULL,
    Prenom VARCHAR2(20) NOT NULL,
    Email VARCHAR2(50) NOT NULL,
    Age NUMBER(3),
    Date_inscription DATE,
    Num_tel CHAR(10),
    Adresse VARCHAR2(100),
    Password VARCHAR2(30) NOT NULL,
    PRIMARY KEY (id_utilisateur),
    CHECK (LENGTH(Password) >= 8)
);

CREATE TABLE Groupe (
    id_groupe NUMBER(10) NOT NULL,
    Nom VARCHAR2(30) NOT NULL,
    Description VARCHAR2(255),
    PRIMARY KEY (id_groupe)
);

CREATE TABLE Logiciel (
    id_logiciel NUMBER(10) NOT NULL,
    Nom VARCHAR2(30) NOT NULL,
    Description VARCHAR2(255),
    PRIMARY KEY (id_logiciel)
);

CREATE TABLE Ticket (
    id_ticket NUMBER(10) NOT NULL,
    Objet VARCHAR2(50) NOT NULL,
    Contenu VARCHAR2(255),
    Logiciel_concerné VARCHAR2(30) NOT NULL,
    id_utilisateur NUMBER,
    Date_envoi DATE,
    Statut VARCHAR2(10),
    PRIMARY KEY (id_ticket),
    FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
);

CREATE TABLE Licence (
    id_licence NUMBER(10) NOT NULL,
    Durée NUMBER(3),
    Prix NUMBER(6, 2) NOT NULL,
    Description VARCHAR2(255),
    PRIMARY KEY (id_licence)
);

CREATE TABLE AchatUtilisateur (
    id_utilisateur NOT NULL,
    id_licence NOT NULL,
    prix NUMBER(6, 2) NOT NULL,
    Date_achat DATE NOT NULL,
    PRIMARY KEY (id_utilisateur, id_licence, Date_achat),
    FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id_utilisateur),
    FOREIGN KEY (id_licence) REFERENCES Licence(id_licence)
    ON DELETE CASCADE
);

CREATE TABLE AchatGroupe (
    id_groupe NOT NULL,
    id_licence NOT NULL,
    prix NUMBER(6, 2) NOT NULL
    Date_achat DATE NOT NULL,
    PRIMARY KEY (id_groupe, id_licence, Date_achat),
    FOREIGN KEY (id_groupe) REFERENCES Groupe(id_groupe),
    FOREIGN KEY (id_licence) REFERENCES Licence(id_licence)
    ON DELETE CASCADE
);

CREATE TABLE Employé (
    id_employé NUMBER(10) NOT NULL,
    Nom VARCHAR2(30),
    Prenom VARCHAR2(20),
    Email VARCHAR2(50) NOT NULL,
    Age NUMBER(3),
    Num_tel CHAR(10),
    Adresse VARCHAR2(100),
    Poste VARCHAR2(20),
    Salaire NUMBER(8, 2),
    Date_arrivée DATE,
    PRIMARY KEY (id_employé)
);

CREATE TABLE Modifie (
    id_employé NOT NULL,
    id_logiciel NOT NULL,
    Date_modification DATE,
    Version VARCHAR2(10),
    PRIMARY KEY (id_employé, id_logiciel, version),
    FOREIGN KEY (id_employé) REFERENCES Employé(id_employé),
    FOREIGN KEY (id_logiciel) REFERENCES Logiciel(id_logiciel)
    ON DELETE CASCADE
);

CREATE TABLE Gère (
    id_employé NOT NULL,
    id_licence NOT NULL,
    Date_modification DATE,
    PRIMARY KEY (id_employé, id_licence, Date_modification),
    FOREIGN KEY (id_employé) REFERENCES Employé(id_employé),
    FOREIGN KEY (id_licence) REFERENCES Licence(id_licence)
    ON DELETE CASCADE
);

CREATE TABLE Appartient (
    id_groupe NOT NULL,
    id_utilisateur NOT NULL,
    PRIMARY KEY (id_groupe, id_utilisateur),
    FOREIGN KEY (id_groupe) REFERENCES Groupe(id_groupe),
    FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id_utilisateur)
    ON DELETE CASCADE
);

CREATE TABLE Inclue (
    id_logiciel NOT NULL,
    id_licence NOT NULL,
    PRIMARY KEY (id_logiciel, id_licence),
    FOREIGN KEY (id_logiciel) REFERENCES Logiciel(id_logiciel),
    FOREIGN KEY (id_licence) REFERENCES Licence(id_licence)
    ON DELETE CASCADE
);


-- B/ Intégrité des données : les triggers

-- Trigger 1 : Un utilisateur ne peut pas acheter une licence si il a déjà acheté la même licence.
CREATE OR REPLACE TRIGGER UtilisateurDoublon
BEFORE INSERT ON AchatUtilisateur
FOR EACH ROW
DECLARE
    nb_achats INTEGER;
	run_time DATE;
BEGIN
    run_time := SYSDATE;
    SELECT COUNT(*) INTO nb_achats
    FROM AchatUtilisateur AU, Licence L 
    WHERE AU.id_utilisateur = :NEW.id_utilisateur
    AND AU.id_licence = :NEW.id_licence
	AND L.id_licence = :NEW.id_licence
	AND L.durée = 30
    AND SYSDATE - AU.date_achat < 30;  -- Calculer la différence en jours pour un mois
	
    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Cet utilisateur a déjà acheté cette licence valable un mois.');
    END IF;

	SELECT COUNT(*) INTO nb_achats
    FROM AchatUtilisateur AU, Licence L 
    WHERE AU.id_utilisateur = :NEW.id_utilisateur
    AND AU.id_licence = :NEW.id_licence
    AND L.id_licence = :NEW.id_licence
    AND L.durée = 365
    AND SYSDATE - AU.date_achat < 365;  -- Calculer la différence en jours pour un an

    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Cet utilisateur a déjà acheté cette licence valable un an.');
    END IF;

END;

-- Trigger 2 : Un utilisateur peut acheter une licence plus chère que celle qu'il a déjà, cela lui donne une réduction du prix de la licence - le prix de sa licence actuelle divisée par le nombre de jours qu'il a utilisé.
CREATE OR REPLACE TRIGGER UtilisateurUpgrade
BEFORE INSERT ON AchatUtilisateur
FOR EACH ROW
DECLARE
    prix_licence_actuelle NUMBER;
    jours_restants NUMBER;
    reduction NUMBER;
BEGIN
    -- Récupérer le prix de la licence actuelle de l'utilisateur
    SELECT l.Prix 
    INTO prix_licence_actuelle
    FROM AchatUtilisateur au
    JOIN Licence l ON au.id_licence = l.id_licence
    WHERE au.id_utilisateur = :NEW.id_utilisateur
    AND ROWNUM = 1;  -- Pour s'assurer de ne récupérer qu'une seule ligne (la plus récente)

    -- Calculer les jours restants dans la période de la licence actuelle
    SELECT (l.Durée - (SYSDATE - au.date_achat)) 
    INTO jours_restants
    FROM AchatUtilisateur au
    JOIN Licence l ON au.id_licence = l.id_licence
    WHERE au.id_utilisateur = :NEW.id_utilisateur
    AND ROWNUM = 1;

    -- Calculer la réduction basée sur les jours restants
    IF jours_restants > 0 THEN
        reduction := prix_licence_actuelle / jours_restants;

        -- Utilisation de l'instruction UPDATE pour modifier les données dans une autre table
        UPDATE Licence
        SET Prix = Prix - reduction
        WHERE id_licence = :NEW.id_licence;

    END IF;
END;

-- Trigger 3 : Un utilisateur qui a acheté la même licence mensuelle 12 fois obtient 1 mois gratuit.
CREATE OR REPLACE TRIGGER ReductionMensuelleUtilisateur
BEFORE INSERT ON AchatUtilisateur
FOR EACH ROW
DECLARE
    nb_achats INTEGER;
BEGIN
    SELECT COUNT(*) INTO nb_achats
    FROM AchatUtilisateur au, Licence l
    WHERE au.id_utilisateur = :NEW.id_utilisateur
    AND au.id_licence = l.id_licence
    AND l.Durée = 30;
    IF MOD(nb_achats, 12) = 0 THEN
        :NEW.Date_achat := :NEW.Date_achat + 30;
    END IF;
END;


-- Trigger 4 : Un groupe ne peut pas acheter une licence si il a déjà acheté la même licence.
CREATE OR REPLACE TRIGGER GroupeDoublon
BEFORE INSERT ON AchatGroupe
FOR EACH ROW
DECLARE
    nb_achats INTEGER;
	run_time DATE;
BEGIN
    run_time := SYSDATE;
    SELECT COUNT(*) INTO nb_achats
    FROM AchatGroupe ag, Licence L 
    WHERE ag.id_groupe = :NEW.id_groupe
    AND ag.id_licence = :NEW.id_licence
	AND L.id_licence = :NEW.id_licence
	AND L.durée = 30
    AND SYSDATE - ag.date_achat < 30;  -- Calculer la différence en jours pour un mois
	
    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Ce groupe a déjà acheté cette licence valable un mois.');
    END IF;

	SELECT COUNT(*) INTO nb_achats
    FROM AchatGroupe ag, Licence L 
    WHERE ag.id_groupe = :NEW.id_groupe
    AND ag.id_licence = :NEW.id_licence
    AND L.id_licence = :NEW.id_licence
    AND L.durée = 365
    AND SYSDATE - ag.date_achat < 365;  -- Calculer la différence en jours pour un an

    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Ce groupe a déjà acheté cette licence valable un an.');
    END IF;
END;

-- Trigger 5 : Un groupe peut acheter une licence plus chère que celle qu'il a déjà, cela lui donne une réduction du prix de la licence - le prix de sa licence actuelle divisée par le nombre de jours qu'il a utilisé.
CREATE OR REPLACE TRIGGER GroupeUpgrade
BEFORE INSERT ON AchatGroupe
FOR EACH ROW
DECLARE
    prix_licence_actuelle NUMBER;
    jours_restants NUMBER;
    reduction NUMBER;
BEGIN
    -- Vérifier si une licence existe pour le groupe
    SELECT COUNT(*)
    INTO prix_licence_actuelle
    FROM AchatGroupe ag
    WHERE ag.id_groupe = :NEW.id_groupe;
	DBMS_OUTPUT.PUT_LINE('Début');

    -- Si une licence existe pour le groupe
    IF prix_licence_actuelle > 0 THEN
        -- Récupérer le prix de la licence actuelle du groupe
        DBMS_OUTPUT.PUT_LINE('licence présente');
        SELECT l.Prix 
        INTO prix_licence_actuelle
        FROM AchatGroupe ag
        JOIN Licence l ON ag.id_licence = l.id_licence
        WHERE ag.id_groupe = :NEW.id_groupe;


        -- Calculer les jours restants dans la période de la licence actuelle
        SELECT (l.durée - (SYSDATE - ag.date_achat)) 
        INTO jours_restants
        FROM AchatGroupe ag
        JOIN Licence l ON ag.id_licence = l.id_licence
        WHERE ag.id_groupe = :NEW.id_groupe;

        -- Calculer la réduction basée sur les jours restants
        IF jours_restants > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Aucune licence présente');
            reduction := prix_licence_actuelle / jours_restants;

            -- Utilisation de l'instruction UPDATE pour modifier les données dans une autre table
            UPDATE Licence
            SET Prix = Prix - reduction
            WHERE id_licence = :NEW.id_licence;
        END IF;
	END IF;
END;

-- Trigger 6 : Supperssion du groupe quand la dernière personne le quitte
CREATE OR REPLACE TRIGGER SuppressionGroupe
AFTER DELETE ON Appartient
FOR EACH ROW
DECLARE
    nb_membres INTEGER;
BEGIN
    -- Compter le nombre de membres restants dans le groupe
    SELECT COUNT(*) INTO nb_membres
    FROM Appartient
    WHERE id_groupe = :OLD.id_groupe;

    -- Si le nombre de membres est égal à 0, supprimer le groupe
    IF nb_membres = 0 THEN
        DELETE FROM Groupe
        WHERE id_groupe = :OLD.id_groupe;
    END IF;
END SuppressionGroupe;




-- C/ Jeu de données

-- Le jeu de données doit être soigneusement préparé et permettre la validation des requêtes
-- complexes qui seront posées par la suite. Il doit y avoir au moins 30 n-uplets par table. Les
-- valeurs choisies pour les attributs doivent être cohérentes avec le schéma de la base.
-- Pour créer vos jeux de données, vous utiliserez tout d’abord des requêtes SQL (insert), puis
-- l’outil de chargement d’Oracle SQL*LOAD pour un chargement massif des données. Pour ce
-- faire, créer un fichier nomfichier.ctl qui contient les définitions suivantes

-- Insert
INSERT INTO Utilisateur VALUES (1, 'Doe', 'John', 'johndoe@gmail.com', 25, '10-jan-2023', '0684052040', '123 Main Street, London', 'password');
INSERT INTO Utilisateur VALUES (2, 'Smith', 'Jane', 'janesmith@gmail.com', 30, '15-feb-2023', '0653052041', '456 Elm Street, London', 'drowssap');
INSERT INTO Utilisateur VALUES (3, 'Johnson', 'Michael', 'michaeljohnson@gmail.com', 28, '20-mar-2023', '0658952582', '789 Oak Street, New York', '12345678');
INSERT INTO Utilisateur VALUES (4, 'Williams', 'Emily', 'emilywilliams@gmail.com', 27, '25-apr-2023', '0648201643', '987 Maple Street, Los Angeles', '88888888');
INSERT INTO Utilisateur VALUES (5, 'Brown', 'David', 'davidbrown@gmail.com', 32, '30-may-2023', '0647016244', '321 Pine Street, Los Angeles', 'darkilluminati:666');
INSERT INTO Utilisateur VALUES (6, 'Taylor', 'Sarah', 'sarahtaylor@gmail.com', 29, '05-jun-2023', '0647125045', '654 Cedar Street, Las Vegas', 'password3');
INSERT INTO Utilisateur VALUES (7, 'Anderson', 'Jessica', 'jessica.anderson@saas.com', 31, '10-jul-2023', '0647144946', '987 Birch Street, London', '98765432');
INSERT INTO Utilisateur VALUES (8, 'Martinez', 'Daniel', 'danielmartinez@yahoo.com', 26, '15-aug-2023', '0647146247', '123 Walnut Street, Shanghai', 'password4');
INSERT INTO Utilisateur VALUES (9, 'Harris', 'Sofia', 'sophia.harris@saas.com', 33, '20-sep-2023', '0647146248', '456 Chestnut Street, Berlin', 'password5');
INSERT INTO Utilisateur VALUES (10, 'Clark', 'Christopher', 'christopherclark@gmail.com', 28, '25-oct-2023', '0647145149', '789 Pineapple Street, Munich', '55555555');
INSERT INTO Utilisateur VALUES (11, 'Lewis', 'Laura', 'lauralewis@gmail.com', 30, '30-nov-2023', '0771507950', '987 Strawberry Street, Turin', 'password6');
INSERT INTO Utilisateur VALUES (12, 'Lee', 'Matthew', 'matthewlee@gmail.com', 27, '05-dec-2023', '0750152079', '123 Mango Street, Washington', 'password7');
INSERT INTO Utilisateur VALUES (13, 'Walker', 'Amanda', 'amandawalker@gmail.com', 49, '10-jan-2024', '0780230528', '456 Banana Street, Tokyo', '77777777');
INSERT INTO Utilisateur VALUES (14, 'Brant', 'Andrew', 'andrewBrant@gmail.com', 31, '15-feb-2024', '0647147433', '789 Orange Street, Tokyo', 'password8');
INSERT INTO Utilisateur VALUES (15, 'Wilson', 'Jessica', 'jessicawilson@outlook.com', 25, '20-mar-2024', '0647147804', '987 Grape Street, New York', 'password9');
INSERT INTO Utilisateur VALUES (16, 'Garcia', 'Maria', 'mariagarcia@outlook.com', 24, '25-apr-2024', '0647147155', '123 Lemon Street, New York', 'ezkjzelkfnkz');
INSERT INTO Utilisateur VALUES (17, 'Rodriguez', 'Juan', 'juanrodriguez@yahoo.com', 29, '30-may-2024', '0647147416', '456 Lime Street, Boston', 'kef,25e0');
INSERT INTO Utilisateur VALUES (18, 'Lopez', 'Carlos', 'carloslopez@gmail.com', 26, '05-jun-2024', '0647147547', '789 Grapefruit Street, Madrid', '123456789');
INSERT INTO Utilisateur VALUES (19, 'Gonzalez', 'Laura', 'lauragonzalez@gmail.com', 28, '10-jul-2024', '0647147108', '987 Watermelon Street, London', '8d1z.ef5');
INSERT INTO Utilisateur VALUES (20, 'Hernandez', 'Pedro', 'pedrohernandez@gmail.com', 31, '15-aug-2024', '0647147159', '123 Apple Street, Los Angeles', 'password12');
INSERT INTO Utilisateur VALUES (21, 'Martinez', 'Ana', 'anamartinez@gmail.com', 27, '20-sep-2024', '0701251060', '456 Orange Street, Barcelona', 'Juanito255+');
INSERT INTO Utilisateur VALUES (22, 'Torres', 'Miguel', 'migueltorres@gmail.com', 50, '25-oct-2024', '0701251061', '789 Banana Street, Copenhagen', '987654321');
INSERT INTO Utilisateur VALUES (23, 'Rivera', 'Sofia', 'sofiarivera@gmail.com', 25, '30-nov-2024', '0647147151', '987 Cherry Street, Madrid', 'password14');
INSERT INTO Utilisateur VALUES (24, 'Perez', 'Diego', 'diegoperez@yahoo.com', 33, '05-dec-2024', '0751097963', '123 Strawberry Street, New York', 'password15');
INSERT INTO Utilisateur VALUES (25, 'Sanchez', 'Isabella', 'isabellasanchez@gmail.com', 29, '10-jan-2025', '0795820514', '456 Raspberry Street, London', 'IsaSan25');
INSERT INTO Utilisateur VALUES (26, 'Ramirez', 'Jose', 'joseramirez@orange.fr', 31, '15-feb-2025', '0740361015', '789 Blueberry Street, Lyon', 'password16');
INSERT INTO Utilisateur VALUES (27, 'Flores', 'Gabriela', 'gabrielaflores@gmail.com', 26, '20-mar-2025', '0794521506', '987 Blackberry Street, Liverpool', '987BSgb*');
INSERT INTO Utilisateur VALUES (28, 'Gomez', 'Andres', 'andresgomez@gmail.com', 28, '25-apr-2025', '0787420052', '123 Cranberry Street, Warsaw', 'aWEsOme42');
INSERT INTO Utilisateur VALUES (29, 'Reyes', 'Valentina', 'valentinareyes@gmail.com', 40, '30-may-2025', '0662352068', '456 Strawberry Street, London', 'password18');
INSERT INTO Utilisateur VALUES (30, 'Morales', 'Camila', 'camilamorales@free.fr', 27, '05-jun-2025', '0688402069', '789 Raspberry Street, Paris', 'password19');

-- Les données ont été générées par IA à partir du 1er insert fait manuellemnt. Quelques valeurs, principalement les numéros de téléphone, les mots de passe et les noms des villes ont ensuite été modifiées pour plus de réalisme.

-- Insert Groupe
INSERT INTO Groupe VALUES (1, 'Dassault Lead Tech', 'Groupe Dassault - Test du SAAS pour de futures opérations commerciales');
INSERT INTO Groupe VALUES (2, 'Air France', 'Groupe Air France');
INSERT INTO Groupe VALUES (3, 'Sanofi', 'Groupe de développement des OpEx');
INSERT INTO Groupe VALUES (4, 'LVMH', 'Département des Opex');
INSERT INTO Groupe VALUES (5, 'General Motors', 'The brand new commercial motors');
INSERT INTO Groupe VALUES (6, 'Groupe 6', 'Groupe de test 6');
INSERT INTO Groupe VALUES (7, 'Groupe 7', 'Groupe de test 7');
INSERT INTO Groupe VALUES (8, 'Groupe 8', 'Groupe de test 8');
INSERT INTO Groupe VALUES (9, 'Groupe 9', 'Groupe de test 9');
INSERT INTO Groupe VALUES (10, 'Le Super Groupe de Camila', 'Groupe de Camila');

-- Insert Logiciel
INSERT INTO Logiciel VALUES (1, 'Logiciel 1', 'Logiciel de test 1');
INSERT INTO Logiciel VALUES (2, 'Logiciel 2', 'Logiciel de test 2');
INSERT INTO Logiciel VALUES (3, 'Logiciel 3', 'Logiciel de test 3');
INSERT INTO Logiciel VALUES (4, 'Logiciel 4', 'Logiciel de test 4');
INSERT INTO Logiciel VALUES (5, 'Logiciel 5', 'Logiciel de test 5');
INSERT INTO Logiciel VALUES (6, 'Logiciel 6', 'Logiciel de test 6');

-- Insert Ticket
INSERT INTO Ticket VALUES (1, 'Bug bizarre', 'Il y a un bug quand on charge le fichier excel dans le Logiciel 1', 'Logiciel 1', 1, '10-jan-2023', 'Traité');
INSERT INTO Ticket VALUES (2, 'Ticket 2', 'Logiciel 2', 'Logiciel 2', 2, '15-feb-2023', 'Traité');
INSERT INTO Ticket VALUES (3, 'Ticket 3', 'Contenu du ticket 3, blabla Logiciel 2', 'Logiciel 2', 3, '20-mar-2023', 'Traité');
INSERT INTO Ticket VALUES (4, 'Logiciel 4', 'Contenu du ticket 4', 'Logiciel 4', 4, '25-apr-2023', 'Traité');
INSERT INTO Ticket VALUES (5, 'Ticket 5', 'Contenu du ticket 5', 'Logiciel 2', 5, '30-may-2023', 'Traité');
INSERT INTO Ticket VALUES (6, 'Ticket 6', 'Contenu du ticket 6', 'Logiciel 1', 6, '05-jun-2023', 'Traité');
INSERT INTO Ticket VALUES (7, 'Logiciel 2', 'Contenu du ticket 7', 'Logiciel 2', 7, '10-jul-2023', 'Traité');
INSERT INTO Ticket VALUES (8, 'Ticket 8', 'Contenu du ticket 8', 'Logiciel 3', 8, '15-aug-2023', 'En attente');
INSERT INTO Ticket VALUES (9, 'logiciel 5', 'Contenu du ticket 9', 'Logiciel 5', 9, '20-sep-2023', 'Traité');
INSERT INTO Ticket VALUES (10, 'Ticket 10', 'Contenu du ticket 10', 'Logiciel 2', 10, '25-oct-2023', 'Traité');
INSERT INTO Ticket VALUES (11, 'Ticket 11', 'Logiciel 6 ticket 11', 'Logiciel 4', 11, '30-nov-2023', 'Traité');
INSERT INTO Ticket VALUES (12, 'Ticket 12', 'Les problème du logiciel 1 est...', 'Logiciel 1', 12, '05-dec-2023', 'Traité');
INSERT INTO Ticket VALUES (13, 'Ticket Logiciel 3', 'Contenu du ticket Logiciel 2 (erreur volontaire)', 'Logiciel 3', 13, '10-jan-2024', 'Traité');
INSERT INTO Ticket VALUES (14, 'Ticket 14', 'Contenu du ticket 14', 'Logiciel 2', 14, '15-feb-2024', 'En attente');
INSERT INTO Ticket VALUES (15, 'Ticket 15', 'Contenu du ticket 15', 'Logiciel 5', 15, '20-mar-2024', 'En attente');
INSERT INTO Ticket VALUES (16, 'Ticket 16', 'Contenu du ticket 16', 'Logiciel 4', 16, '25-apr-2024', 'Traité');
INSERT INTO Ticket VALUES (17, 'Ticket 17', 'Contenu du ticket 17', 'Logiciel 3', 17, '30-may-2024', 'En attente');
INSERT INTO Ticket VALUES (18, 'Ticket 18', 'Contenu du ticket 18', 'Logiciel 2', 18, '05-jun-2024', 'Traité');
INSERT INTO Ticket VALUES (19, 'Ticket 19', 'Contenu du ticket 19', 'Logiciel 1', 19, '10-jul-2024', 'Traité');
INSERT INTO Ticket VALUES (20, 'Ticket 20', 'Contenu du ticket 20', 'Logiciel 1', 20, '15-aug-2024', 'En attente');
INSERT INTO Ticket VALUES (21, 'Ticket 21', 'Contenu du ticket 21', 'Logiciel 6', 21, '20-sep-2024', 'En attente');
INSERT INTO Ticket VALUES (22, 'Ticket 22', 'Contenu du ticket 22', 'Logiciel 5', 22, '25-oct-2024', 'En attente');
INSERT INTO Ticket VALUES (23, 'Ticket 23', 'Contenu du ticket 23', 'Logiciel 4', 23, '30-nov-2024', 'En attente');
INSERT INTO Ticket VALUES (24, 'Ticket 24', 'Contenu du ticket 24', 'Logiciel 2', 24, '05-dec-2024', 'En attente');
INSERT INTO Ticket VALUES (25, 'Ticket 25', 'Contenu du ticket 25', 'Logiciel 3', 25, '10-jan-2025', 'Traité');
INSERT INTO Ticket VALUES (26, 'Ticket 26', 'Contenu du ticket 26', 'Logiciel 1', 26, '15-feb-2025', 'En attente');
INSERT INTO Ticket VALUES (27, 'Ticket 27', 'Contenu du ticket 27', 'Logiciel 2', 27, '20-mar-2025', 'En attente');
INSERT INTO Ticket VALUES (28, 'Ticket 28', 'Contenu du ticket 28', 'Logiciel 5', 28, '25-apr-2025', 'En attente');
INSERT INTO Ticket VALUES (29, 'Ticket 29', 'Contenu du ticket 29', 'Logiciel 6', 29, '30-may-2025', 'En attente');
INSERT INTO Ticket VALUES (30, 'Ticket 30', 'Contenu du ticket 30', 'Logiciel 3', 30, '05-jun-2025', 'En attente');

-- Insert Licence
INSERT INTO Licence VALUES (1, 30, 10, 'Licence 1');
INSERT INTO Licence VALUES (2, 365, 100, 'Licence 2');
INSERT INTO Licence VALUES (3, 30, 19.90, 'Licence 3');
INSERT INTO Licence VALUES (4, 365, 150, 'Licence 4');
INSERT INTO Licence VALUES (5, 30, 49.90, 'Licence 5');
INSERT INTO Licence VALUES (6, 365, 200, 'Licence 6');
select * from Licence;

-- Insert AchatUtilisateur
INSERT INTO AchatUtilisateur VALUES (1, 1, 10, '10-feb-2023');
INSERT INTO AchatUtilisateur VALUES (2, 2, 100, '15-feb-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, 10, '10-mar-2023');
INSERT INTO AchatUtilisateur VALUES (3, 3, 19.90, '20-mar-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, 10, '10-apr-2023');
INSERT INTO AchatUtilisateur VALUES (3, 3, 19.90, '20-apr-2023');
INSERT INTO AchatUtilisateur VALUES (4, 4, 150, '25-apr-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, 10, '10-may-2023');
INSERT INTO AchatUtilisateur VALUES (4, 2, 100, '26-may-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, 49.90, '30-may-2023');
INSERT INTO AchatUtilisateur VALUES (6, 6, 200, '05-jun-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, 10, '10-jun-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, 49.90 ,'30-jun-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, 10, '10-jul-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, 49.90, '30-jul-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, 10, '10-aug-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, 49.90, '30-aug-2023');
INSERT INTO AchatUtilisateur VALUES (1, 2, 100, '10-sep-2023');
INSERT INTO AchatUtilisateur VALUES (8, 2, 100, '10-oct-2023');
INSERT INTO AchatUtilisateur VALUES (9, 4, 150, '25-nov-2023');
INSERT INTO AchatUtilisateur VALUES (10, 5, 49.90, '30-dec-2023');
INSERT INTO AchatUtilisateur VALUES (11, 6, 200, '05-jan-2024');
INSERT INTO AchatUtilisateur VALUES (10, 5, 49.90, '30-jan-2024');
INSERT INTO AchatUtilisateur VALUES (12, 6, 200, '05-feb-2024');
INSERT INTO AchatUtilisateur VALUES (2, 2, 100, '15-feb-2024');
INSERT INTO AchatUtilisateur VALUES (10, 5, 49.90, '29-feb-2024');
INSERT INTO AchatUtilisateur VALUES (13, 1, 10, '10-mar-2024');
INSERT INTO AchatUtilisateur VALUES (13, 1, 10, '10-apr-2024');
INSERT INTO AchatUtilisateur VALUES (14, 2, 100, '15-apr-2024');
INSERT INTO AchatUtilisateur VALUES (4, 4, 150, '25-apr-2024');
INSERT INTO AchatUtilisateur VALUES (15, 3, 19.90, '20-may-2024');
INSERT INTO AchatUtilisateur VALUES (6, 6, 200, '05-jun-2024');
INSERT INTO AchatUtilisateur VALUES (16, 4, 150, '25-jun-2024');
INSERT INTO AchatUtilisateur VALUES (17, 5, 49.90, '30-jul-2024');
INSERT INTO AchatUtilisateur VALUES (18, 6, 200, '05-aug-2024');
INSERT INTO AchatUtilisateur VALUES (17, 5, 49.90, '30-aug-2024');
INSERT INTO AchatUtilisateur VALUES (19, 1, 10, '10-sep-2024');
INSERT INTO AchatUtilisateur VALUES (19, 1, 10, '10-oct-2024');
INSERT INTO AchatUtilisateur VALUES (20, 2, 100, '15-oct-2024');
INSERT INTO AchatUtilisateur VALUES (19, 1, 10, '10-nov-2024');
INSERT INTO AchatUtilisateur VALUES (21, 4, 150, '20-nov-2024');
select * from AchatUtilisateur;

-- Insert AchatGroupe
INSERT INTO AchatGroupe VALUES (1, 4, 150, '10-jan-2023');
INSERT INTO AchatGroupe VALUES (2, 2, 100, '15-feb-2023');
INSERT INTO AchatGroupe VALUES (3, 6, 200, '20-mar-2023');
INSERT INTO AchatGroupe VALUES (4, 6, 200, '25-apr-2023');
INSERT INTO AchatGroupe VALUES (5, 4, 150, '30-may-2023');
INSERT INTO AchatGroupe VALUES (6, 4, 150, '05-jun-2023');
INSERT INTO AchatGroupe VALUES (7, 4, 150, '10-jul-2023');
INSERT INTO AchatGroupe VALUES (8, 2, 100, '15-aug-2023');
INSERT INTO AchatGroupe VALUES (9, 2, 100, '20-sep-2023');
INSERT INTO AchatGroupe VALUES (10, 6, 200, '25-oct-2023');
INSERT INTO AchatGroupe VALUES (1, 4, 150, '10-jan-2024');
INSERT INTO AchatGroupe VALUES (2, 2, 100, '15-feb-2024');
INSERT INTO AchatGroupe VALUES (3, 6, 200, '20-mar-2024');
INSERT INTO AchatGroupe VALUES (4, 6, 200, '25-apr-2024');
INSERT INTO AchatGroupe VALUES (5, 4, 150, '30-may-2024');
INSERT INTO AchatGroupe VALUES (6, 4, 150, '05-jun-2024');
INSERT INTO AchatGroupe VALUES (7, 4, 150, '10-jul-2024');
INSERT INTO AchatGroupe VALUES (8, 2, 100, '15-aug-2024');
INSERT INTO AchatGroupe VALUES (9, 2, 100, '20-sep-2024');
INSERT INTO AchatGroupe VALUES (10, 6, 200, '25-oct-2024');
INSERT INTO AchatGroupe VALUES (1, 4, 150, '10-jan-2025');
INSERT INTO AchatGroupe VALUES (2, 2, 100, '15-feb-2025');
INSERT INTO AchatGroupe VALUES (3, 6, 200, '20-mar-2025');
INSERT INTO AchatGroupe VALUES (4, 6, 200, '25-apr-2025');
INSERT INTO AchatGroupe VALUES (5, 4, 150, '30-may-2025');
INSERT INTO AchatGroupe VALUES (6, 4, 150, '05-jun-2025');
INSERT INTO AchatGroupe VALUES (7, 4, 150, '10-jul-2025');
INSERT INTO AchatGroupe VALUES (8, 2, 100, '15-aug-2025');
INSERT INTO AchatGroupe VALUES (9, 2, 100, '20-sep-2025');
INSERT INTO AchatGroupe VALUES (10, 6, 200, '25-oct-2025');
select * from AchatGroupe;

-- Insert Employé
INSERT INTO Employé VALUES (1, 'Johnson', 'David', 'david.johnson@saas.com', 28, '0611004081', '10 Downing Street, London', 'Chef', '60000.00', '01-mar-2022');
INSERT INTO Employé VALUES (2, 'Brown', 'Emily', 'emily.brown@saas.com', 27, '0624542130', '25 Downing Street, London', 'Commercial', '40000.00', '01-mar-2022');
INSERT INTO Employé VALUES (3, 'Wilson', 'Michael', 'michael.wilson@saas.com', 24, '0775680101', '49 Rue de la Paix, Paris', 'Développeur', '50000.00', '01-mar-2022');
INSERT INTO Employé VALUES (4, 'Shaft', 'Sarah', 'sarah.shaft@saas.com', 25, '0647147152', '310 Main Street, London', 'Développeur', '60000.00', '20-jan-2023');
INSERT INTO Employé VALUES (5, 'Daniel', 'Jack', 'jack.daniel@saas.com', 34, '0682056204', '37 Uncool Street, London', 'Commercial', '50000.00', '13-apr-2023');
INSERT INTO Employé VALUES (6, 'Smith', 'Jennifer', 'jennifer.smith@saas.com', 30, '0684024055', '123 Avenue des Champs-Élysées, Paris', 'Développeur', '55000.00', '05-may-2023');
INSERT INTO Employé VALUES (7, 'Taylor', 'Andrew', 'andrew.taylor@saas.com', 29, '0678451236', '456 Broadway, New York', 'Développeur', '45000.00', '09-may-2023');
INSERT INTO Employé VALUES (8, 'Anderson', 'Jessica', 'jessica.anderson@saas.com', 31, '0647144946', '987 Birch Street, London', 'Commercial', '55000.00', '01-jun-2023');
INSERT INTO Employé VALUES (9, 'Thomas', 'Matthew', 'matthew.thomas@saas.com', 31, '0686048521', '987 Wall Street, New York', 'Support', '38000.00', '25-jul-2023');
INSERT INTO Employé VALUES (10, 'Harris', 'Sophia', 'sophia.harris@saas.com', 33, '0647146248', '456 Chestnut Street, Berlin', 'Développeur', '55000.00', '14-sep-2023');
INSERT INTO Employé VALUES (11, 'Clark', 'Daniel', 'daniel.clark@saas.com', 28, '0651205400', '321 Park Avenue, New York', 'Commercial', '45000.00', '26-nov-2023');
INSERT INTO Employé VALUES (12, 'Lewis', 'Olivia', 'olivia.lewis@saas.com', 25, '0745456013', '852 Rodeo Drive, Los Angeles', 'Support', '35000.00', '30-nov-2023');
INSERT INTO Employé VALUES (13, 'Walker', 'James', 'james.walker@saas.com', 29, '0687451236', '963 Sunset Boulevard, Los Angeles', 'Commercial', '45000.00', '12-may-2024');
INSERT INTO Employé VALUES (14, 'Brant', 'Ava', 'ava.brant@saas.com', 26, '0654789321', '741 Vine Street, Los Angeles', 'Support', '35000.00', '27-jul-2024');
INSERT INTO Employé VALUES (15, 'Young', 'William', 'william.young@saas.com', 30, '0654024060', '369 Hollywood Boulevard, Los Angeles', 'Commercial', '45000.00', '11-oct-2024');

-- Insert Modifie
INSERT INTO Modifie VALUES (1, 1, '10-mar-2022', '0.1');
INSERT INTO Modifie VALUES (1, 1, '17-apr-2022', '0.2');
INSERT INTO Modifie VALUES (3, 1, '29-may-2022', '0.3');
INSERT INTO Modifie VALUES (1, 1, '20-jun-2022', '0.4');
INSERT INTO Modifie VALUES (3, 1, '18-jul-2022', '0.5');
INSERT INTO Modifie VALUES (3, 1, '10-sep-2022', '0.6');
INSERT INTO Modifie VALUES (3, 1, '15-nov-2022', '0.7');
INSERT INTO Modifie VALUES (3, 1, '14-jan-2022', '0.8');
INSERT INTO Modifie VALUES (4, 1, '19-mar-2022', '0.9');
INSERT INTO Modifie VALUES (1, 1, '24-apr-2023', '1.0');
INSERT INTO Modifie VALUES (3, 1, '11-may-2023', '1.1');
INSERT INTO Modifie VALUES (6, 1, '29-jun-2023', '1.2');
INSERT INTO Modifie VALUES (7, 2, '10-jul-2023', '0.1');
INSERT INTO Modifie VALUES (4, 1, '15-aug-2023', '1.3');
INSERT INTO Modifie VALUES (3, 2, '20-sep-2023', '0.2');
INSERT INTO Modifie VALUES (6, 2, '25-oct-2023', '1.0');
INSERT INTO Modifie VALUES (7, 1, '30-nov-2023', '1.4');
INSERT INTO Modifie VALUES (10, 3, '20-dec-2023', '0.1');
INSERT INTO Modifie VALUES (12, 3, '25-jan-2024', '0.2');
INSERT INTO Modifie VALUES (3, 3, '29-feb-2024', '0.3');
INSERT INTO Modifie VALUES (4, 4, '05-mar-2024', '0.1');
INSERT INTO Modifie VALUES (10, 3, '10-apr-2024', '0.4');
INSERT INTO Modifie VALUES (12, 3, '15-may-2024', '0.6');
INSERT INTO Modifie VALUES (7, 2, '20-jun-2024', '1.1');
INSERT INTO Modifie VALUES (6, 5, '25-jul-2024', '0.1');
INSERT INTO Modifie VALUES (12, 3, '30-aug-2024', '0.3');
INSERT INTO Modifie VALUES (4, 4, '05-sep-2024', '0.2');
INSERT INTO Modifie VALUES (10, 3, '10-oct-2024', '0.7');
INSERT INTO Modifie VALUES (12, 3, '15-nov-2024', '0.8');
INSERT INTO Modifie VALUES (7, 2, '20-dec-2024', '1.2');
INSERT INTO Modifie VALUES (6, 5, '25-jan-2025', '0.2');
INSERT INTO Modifie VALUES (12, 3, '28-feb-2025', '0.9');
INSERT INTO Modifie VALUES (4, 4, '05-mar-2025', '0.3');
INSERT INTO Modifie VALUES (10, 3, '10-apr-2025', '1.0');
INSERT INTO Modifie VALUES (12, 3, '15-may-2025', '1.1');
INSERT INTO Modifie VALUES (7, 2, '20-jun-2025', '1.3');
INSERT INTO Modifie VALUES (6, 5, '25-jul-2025', '0.4');
INSERT INTO Modifie VALUES (3, 1, '30-aug-2025', '1.5');
INSERT INTO Modifie VALUES (7, 4, '05-sep-2025', '1.0');

-- Insert Gère
INSERT INTO Gère VALUES (1, 1, '20-jun-2022');
INSERT INTO Gère VALUES (2, 3, '18-jul-2022');
INSERT INTO Gère VALUES (2, 3, '10-sep-2022');
INSERT INTO Gère VALUES (2, 3, '15-nov-2022');
INSERT INTO Gère VALUES (2, 3, '14-jan-2023');
INSERT INTO Gère VALUES (1, 4, '19-mar-2023');
INSERT INTO Gère VALUES (1, 1, '24-apr-2023');
INSERT INTO Gère VALUES (1, 3, '11-may-2023');
INSERT INTO Gère VALUES (5, 4, '29-jun-2023');
INSERT INTO Gère VALUES (5, 4, '10-jul-2023');
INSERT INTO Gère VALUES (2, 3, '15-aug-2023');
INSERT INTO Gère VALUES (8, 4, '20-sep-2023');
INSERT INTO Gère VALUES (9, 1, '25-oct-2023');
INSERT INTO Gère VALUES (2, 2, '30-nov-2023');
INSERT INTO Gère VALUES (2, 4, '20-dec-2023');
INSERT INTO Gère VALUES (8, 5, '25-jan-2024');
INSERT INTO Gère VALUES (2, 3, '29-feb-2024');
INSERT INTO Gère VALUES (5, 4, '05-mar-2024');
INSERT INTO Gère VALUES (2, 5, '10-apr-2024');
INSERT INTO Gère VALUES (5, 6, '15-may-2024');
INSERT INTO Gère VALUES (2, 2, '20-jun-2024');
INSERT INTO Gère VALUES (8, 2, '25-jul-2024');
INSERT INTO Gère VALUES (8, 1, '30-aug-2024');
INSERT INTO Gère VALUES (9, 5, '05-sep-2024');
INSERT INTO Gère VALUES (5, 6, '10-oct-2024');
INSERT INTO Gère VALUES (9, 2, '15-nov-2024');
INSERT INTO Gère VALUES (8, 2, '20-dec-2024');
INSERT INTO Gère VALUES (2, 5, '25-jan-2025');
INSERT INTO Gère VALUES (5, 1, '28-feb-2025');
INSERT INTO Gère VALUES (8, 6, '05-mar-2025');
INSERT INTO Gère VALUES (5, 2, '10-apr-2025');
    
-- Insert Appartient
INSERT INTO Appartient VALUES (1, 1);
INSERT INTO Appartient VALUES (1, 2);
INSERT INTO Appartient VALUES (1, 5);
INSERT INTO Appartient VALUES (1, 6);
INSERT INTO Appartient VALUES (1, 8);
INSERT INTO Appartient VALUES (2, 9);
INSERT INTO Appartient VALUES (2, 10);
INSERT INTO Appartient VALUES (2, 11);
INSERT INTO Appartient VALUES (2, 13);
INSERT INTO Appartient VALUES (2, 15);
INSERT INTO Appartient VALUES (3, 12);
INSERT INTO Appartient VALUES (3, 14);
INSERT INTO Appartient VALUES (3, 16);
INSERT INTO Appartient VALUES (3, 18);
INSERT INTO Appartient VALUES (4, 5);
INSERT INTO Appartient VALUES (4, 17);
INSERT INTO Appartient VALUES (4, 18);
INSERT INTO Appartient VALUES (4, 21);
INSERT INTO Appartient VALUES (5, 4);
INSERT INTO Appartient VALUES (5, 24);
INSERT INTO Appartient VALUES (5, 26);
INSERT INTO Appartient VALUES (6, 27);
INSERT INTO Appartient VALUES (7, 7);
INSERT INTO Appartient VALUES (7, 17);
INSERT INTO Appartient VALUES (7, 22);
INSERT INTO Appartient VALUES (7, 23);
INSERT INTO Appartient VALUES (7, 25);
INSERT INTO Appartient VALUES (8, 5);
INSERT INTO Appartient VALUES (8, 9);
INSERT INTO Appartient VALUES (8, 13);
INSERT INTO Appartient VALUES (8, 19);
INSERT INTO Appartient VALUES (8, 15);
INSERT INTO Appartient VALUES (9, 29);
INSERT INTO Appartient VALUES (9, 30);
INSERT INTO Appartient VALUES (9, 28);
INSERT INTO Appartient VALUES (10, 30);

-- Insert Inclue
INSERT INTO Inclue VALUES (1, 1);
INSERT INTO Inclue VALUES (1, 2);
INSERT INTO Inclue VALUES (2, 1);
INSERT INTO Inclue VALUES (2, 2);
INSERT INTO Inclue VALUES (3, 1);
INSERT INTO Inclue VALUES (3, 2);
INSERT INTO Inclue VALUES (3, 3);
INSERT INTO Inclue VALUES (3, 4);
INSERT INTO Inclue VALUES (4, 1);
INSERT INTO Inclue VALUES (4, 2);
INSERT INTO Inclue VALUES (4, 3);
INSERT INTO Inclue VALUES (4, 4);
INSERT INTO Inclue VALUES (5, 1);
INSERT INTO Inclue VALUES (5, 2);
INSERT INTO Inclue VALUES (5, 3);
INSERT INTO Inclue VALUES (5, 4);
INSERT INTO Inclue VALUES (5, 5);
INSERT INTO Inclue VALUES (6, 1);
INSERT INTO Inclue VALUES (6, 2);
INSERT INTO Inclue VALUES (6, 3);
INSERT INTO Inclue VALUES (6, 4);
INSERT INTO Inclue VALUES (6, 5);

--D/ Manipulation des données

-- Quels sont tous les utilisateurs ?
select * from Utilisateur;
-- Quels sont tous les groupes ?
select * from Groupe;
-- Quels sont tous les logiciels ?
select * from Logiciel;
-- Quels sont tous les ticlets ?
select * from Ticket;
-- Quelles sont toutes les licences
select * from Licence;
-- Quels sont tous les achats réalisés par des utilisateurs triés par date d'achat ?
select * from AchatUtilisateur
    order by date_achat;
-- Quels sont tous les achats réalisés par des groupes ?
select * from AchatGroupe;
-- Quels sont tous les employés ?
select * from Employé;
-- Quelles sont toutes les modifications faites aux logiciels ?
select * from Modifie;
-- Quelles sont toutes les modifications faites aux licences ?
select * from Gère;
-- Quel utilisateur appartient à quel groupe ?
select * from Appartient;
-- Quels logiciels sont inclus dans quelles licences ?
select * from Inclue;

-- Quels groupes et combien ont-ils acheté de licences ?
select distinct g.Nom, count(ag.id_groupe) as "Nombre de licences achetées"
from Groupe g, AchatGroupe ag
where g.id_groupe = ag.id_groupe
group by g.Nom;

-- Combien de licences ont acheté en moyenne les groupes ?
select avg(nb_licences) as "Nombre de licences achetées en moyenne par groupe"
from (select count(ag.id_groupe) as nb_licences
    from Groupe g, AchatGroupe ag
    where g.id_groupe = ag.id_groupe
    group by g.Nom);

-- Combien d'employés sont Développeurs ? Support ? Commercial ?
select count(*) as "Nombre d'employés Développeurs"
from Employé
where Poste = 'Développeur';
select count(*) as "Nombre d'employés Support"
from Employé
where Poste = 'Support';
select count(*) as "Nombre d'employés Commercial"
from Employé
where Poste = 'Commercial';

-- Combien d'employés dans la SAAS ?
select count(*) as "Nombre d'employés dans la SAAS"
from Employé;

-- Quelle est la moyenne des salaires des développeurs ? du support ? des commerciaux ? de tous ?
select avg(Salaire) as "Salaire moyen des Développeurs"
from Employé
where Poste = 'Développeur';
select avg(Salaire) as "Salaire moyen du Support"
from Employé
where Poste = 'Support';
select avg(Salaire) as "Salaire moyen des Commerciaux"
from Employé
where Poste = 'Commercial';
select avg(Salaire) as "Salaire moyen de tous les employés"
from Employé;

-- Combien de tickets ont été traités ? Combien sont en attente ?
select count(*) as "Nombre de tickets traités"
from Ticket
where Statut = 'Traité';
select count(*) as "Nombre de tickets en attente"
from Ticket
where Statut = 'En attente';

-- Quels sont les utilisateurs qui sont aussi employés ? (même email)
select u.Nom, u.Prenom, u.Email
from Utilisateur u, Employé e
where u.Email = e.Email;

-- Combien de ventes a fait le SAAS ? Combien d’argent ?
select count(*) as "Nombre de ventes"
from AchatUtilisateur;
select sum(Prix) as "Argent gagné"
from AchatUtilisateur au, Licence l
where au.id_licence = l.id_licence;

-- Quelle est la licence la plus vendue ?
select l.id_licence, count(au.id_licence) as "Nombre de ventes"
from AchatUtilisateur au, Licence l
where au.id_licence = l.id_licence
group by l.id_licence
order by count(au.id_licence) desc;

-- Quels utilisateurs ont acheté plusieurs fois des licences ?
select u.Nom, u.Prenom, u.Email, count(au.id_licence) as "Nombre de licences"
from Utilisateur u, AchatUtilisateur au
where u.id_utilisateur = au.id_utilisateur
group by u.Nom, u.Prenom, u.Email
having count(au.id_licence) > 1;

-- Quels sont les utilisateurs qui ont plusieurs licences ? (donc personnelle et de groupe) - WIP
select distinct u.Nom, u.Prenom, u.Email, l.id_licence as "Licence personnelle", l2.id_licence as "Licence du groupe", g.Nom
from Utilisateur u, AchatUtilisateur au, Licence l, AchatGroupe ag, Licence l2, Groupe g
where u.id_utilisateur = au.id_utilisateur
and au.id_licence = l.id_licence
and u.id_utilisateur = ag.id_groupe
and ag.id_licence = l2.id_licence
and l.id_licence != l2.id_licence
order by u.Email;

-- Quels utilisateurs ont le logiciel donné (4) ?
select distinct u.Nom, u.Prenom, u.Email
from Utilisateur u, AchatUtilisateur au, Licence l, Inclue i
where u.id_utilisateur = au.id_utilisateur
and au.id_licence = l.id_licence
and l.id_licence = i.id_licence
and i.id_logiciel = 4;

-- Quels logiciels ont été modifiés le plus suite à des Ticket ? - WIP
-- SELECT l.Nom AS "Nom du logiciel", COUNT(*) AS "Nombre de modifications"
-- FROM Ticket t, Modifie m
-- JOIN Logiciel l ON m.id_logiciel = l.id_logiciel
-- WHERE t.Objet LIKE CONCAT('%', l.Nom, '%') OR t.Contenu LIKE CONCAT('%', l.Nom, '%')
-- GROUP BY l.Nom
-- ORDER BY COUNT(*) DESC;

-- E/ Vues

-- Vue 1 : Affiche les détails des licences achetées par les utilisateurs.
CREATE VIEW UtilisateurAchatLicence AS
SELECT U.id_utilisateur, U.Nom, U.Prenom, A.Date_achat, L.*
FROM Utilisateur U
JOIN AchatUtilisateur A ON U.id_utilisateur = A.id_utilisateur
JOIN Licence L ON A.id_licence = L.id_licence;
SELECT * FROM UtilisateurAchatLicence;

-- Vue 2 : Affiche les détails des licences achetées par les groupes.
CREATE VIEW GroupeAchatLicence AS
SELECT G.id_groupe, G.Nom, A.Date_achat, L.*
FROM Groupe G
JOIN AchatGroupe A ON G.id_groupe = A.id_groupe
JOIN Licence L ON A.id_licence = L.id_licence;
SELECT * FROM GroupeAchatLicence;

-- Vue 3 : Affiche les détails des modifications de logiciels effectuées par les employés.
CREATE VIEW EmployeModifieLogiciel AS
SELECT E.id_employé, E.Nom AS "Nom Employe", E.Prenom, M.Date_modification, M.Version, L.*
FROM Employé E
JOIN Modifie M ON E.id_employé = M.id_employé
JOIN Logiciel L ON M.id_logiciel = L.id_logiciel;
SELECT * FROM EmployeModifieLogiciel;

-- Vue 4 : Affiche les détails de la gestion des licences par les employés.
CREATE VIEW EmployeGereLicence AS
SELECT E.id_employé, E.Nom as "Nom Employe", E.Prenom, G.Date_modification, L.*
FROM Employé E
JOIN Gère G ON E.id_employé = G.id_employé
JOIN Licence L ON G.id_licence = L.id_licence;
SELECT * FROM EmployeGereLicence;

-- Vue 5 : NombreUtilisateursParGroupe récupère le nombre d'utilisateurs par groupe.
CREATE VIEW NombreUtilisateursParGroupe AS
SELECT G.id_groupe, G.Nom, COUNT(A.id_utilisateur) AS Nombre_Utilisateurs
FROM Groupe G LEFT JOIN Appartient A ON G.id_groupe = A.id_groupe
GROUP BY G.id_groupe, G.Nom;
SELECT * FROM NombreUtilisateursParGroupe;

-- Vue 6 : StatistiquesUtilisateur récupère les utilisateurs ainsi que le nombre d'achat de licences et les dépenses moyennes de chaque utilisateur.
CREATE VIEW StatistiquesUtilisateur AS
SELECT U.id_utilisateur, U.Nom, U.Prenom, COUNT(A.id_licence) AS Nombre_Achats, AVG(L.Prix) AS Prix_Moyen
FROM Utilisateur U LEFT JOIN AchatUtilisateur A ON U.id_utilisateur = A.id_utilisateur LEFT JOIN Licence L ON A.id_licence = L.id_licence
GROUP BY U.id_utilisateur, U.Nom, U.Prenom;
SELECT * FROM StatistiquesUtilisateur;

-- Vue 7 : StatistiquesGroupe récupère les groupes ainsi que le nombre d'achat de licences et la dépense totale du groupe.
CREATE VIEW StatistiquesGroupe AS
SELECT G.id_groupe, G.Nom, COUNT(A.id_licence) AS Nombre_Achats, SUM(L.Prix) AS Prix_Total
FROM Groupe G LEFT JOIN AchatGroupe A ON G.id_groupe = A.id_groupe LEFT JOIN Licence L ON A.id_licence = L.id_licence
GROUP BY G.id_groupe, G.Nom;
SELECT * FROM StatistiquesGroupe;

-- Vue 8 : SalaireMoyenParPoste récupère la moyenne des salaires des employés selon leur poste.
CREATE OR REPLACE VIEW SalaireMoyenParPoste AS
SELECT Poste, AVG(Salaire) AS Salaire_Moyen
FROM Employé
GROUP BY Poste;
SELECT * FROM SalaireMoyenParPoste;

-- GRANT SELECT ON UtilisateurAchatLicence TO Employé WHERE Poste = 'Commercial';
-- GRANT SELECT ON GroupeAchatLicence TO Employé WHERE Poste = 'Commercial';
-- GRANT SELECT ON EmployeModifieLogiciel TO Employé WHERE Poste = 'Développeur';
-- GRANT SELECT ON EmployeGereLicence TO Employé WHERE Poste = 'Commercial';
-- -- Donner l'accès aux membres du groupe ? Si oui, comment ?
-- GRANT SELECT ON NombreUtilisateursParGroupe TO Employé WHERE Poste = 'Commercial';
-- GRANT SELECT ON StatistiquesUtilisateur TO Employé WHERE Poste = 'Commercial';
-- GRANT SELECT ON StatistiquesGroupe TO Employé WHERE Poste = 'Commercial';
-- GRANT SELECT ON SalaireMoyenParPoste TO Employé WHERE Poste = 'Chef';

