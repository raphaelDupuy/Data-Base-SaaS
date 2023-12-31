-- A/ Création du schéma de la base de données

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
    Durée NUMBER(3) CHECK (Durée IN (30, 365)) NOT NULL, -- Il s'agit du plus proche que l'on puisse faire d'un Enum dans Sql Live
    Prix NUMBER(6, 2) NOT NULL,
    Description VARCHAR2(255),
    PRIMARY KEY (id_licence)
);

CREATE TABLE AchatUtilisateur (
    id_utilisateur NOT NULL,
    id_licence NOT NULL,
    Date_achat DATE NOT NULL,
    PRIMARY KEY (id_utilisateur, id_licence, Date_achat),
    FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id_utilisateur),
    FOREIGN KEY (id_licence) REFERENCES Licence(id_licence)
    ON DELETE CASCADE
);

CREATE TABLE AchatGroupe (
    id_groupe NOT NULL,
    id_licence NOT NULL,
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
    Poste VARCHAR2(20) CHECK (Poste IN ('Chef', 'Développeur', 'Commercial', 'Support')) NOT NULL, -- Il s'agit du plus proche que l'on puisse faire d'un Enum dans Sql Live
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

CREATE TABLE Récupère (
    id_employé NOT NULL,
    id_ticket NOT NULL,
    Date_récupération DATE,
    PRIMARY KEY (id_employé, id_ticket, Date_récupération),
    FOREIGN KEY (id_employé) REFERENCES Employé(id_employé),
    FOREIGN KEY (id_ticket) REFERENCES Ticket(id_ticket)
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
BEGIN
    SELECT COUNT(*) INTO nb_achats
    FROM AchatUtilisateur AU, Licence L 
    WHERE AU.id_utilisateur = :NEW.id_utilisateur
    AND AU.id_licence = :NEW.id_licence
	AND L.id_licence = :NEW.id_licence
	AND L.durée = 30
    AND :NEW.date_achat - AU.date_achat < 30;  -- Calculer la différence en jours pour un mois
	
    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Cet utilisateur a déjà acheté cette licence valable un mois.');
    END IF;

	SELECT COUNT(*) INTO nb_achats
    FROM AchatUtilisateur AU, Licence L 
    WHERE AU.id_utilisateur = :NEW.id_utilisateur
    AND AU.id_licence = :NEW.id_licence
    AND L.id_licence = :NEW.id_licence
    AND L.durée = 365
    AND :NEW.date_achat - AU.date_achat < 365;  -- Calculer la différence en jours pour un an

    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Cet utilisateur a déjà acheté cette licence valable un an.');
    END IF;

END;

-- Trigger 2 : Un utilisateur qui a acheté la même licence mensuelle 12 fois obtient 1 mois gratuit.
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

-- Trigger 3 : Un groupe ne peut pas acheter une licence si il a déjà acheté la même licence.
CREATE OR REPLACE TRIGGER GroupeDoublon
BEFORE INSERT ON AchatGroupe
FOR EACH ROW
DECLARE
    nb_achats INTEGER;
BEGIN
    SELECT COUNT(*) INTO nb_achats
    FROM AchatGroupe ag, Licence L 
    WHERE ag.id_groupe = :NEW.id_groupe
    AND ag.id_licence = :NEW.id_licence
	AND L.id_licence = :NEW.id_licence
	AND L.durée = 30
    AND :NEW.date_achat - ag.date_achat < 30;  -- Calculer la différence en jours pour un mois
	
    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Ce groupe a déjà acheté cette licence valable un mois.');
    END IF;

	SELECT COUNT(*) INTO nb_achats
    FROM AchatGroupe ag, Licence L 
    WHERE ag.id_groupe = :NEW.id_groupe
    AND ag.id_licence = :NEW.id_licence
    AND L.id_licence = :NEW.id_licence
    AND L.durée = 365
    AND :NEW.date_achat - ag.date_achat < 365;  -- Calculer la différence en jours pour un an

    IF nb_achats > 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'Ce groupe a déjà acheté cette licence valable un an.');
    END IF;
END;

-- Trigger 4 : Vérification que le ticket à gerer est bien en attente
CREATE OR REPLACE TRIGGER TraitementTicketEtat
BEFORE INSERT ON Récupère
FOR EACH ROW
DECLARE
	etat VARCHAR(10);
BEGIN
    -- Récupérer l'état actuel du Ticket à gerer
    SELECT T.Statut INTO etat
    FROM Ticket T
    WHERE T.id_ticket = :NEW.id_ticket;
	
	IF etat = 'Traité' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Ce Ticket a déjà été géré');
	END IF;
END;

-- Trigger 5 : Vérifier que la date est valide
CREATE OR REPLACE TRIGGER TraitementTicketDate
BEFORE INSERT ON Récupère
FOR EACH ROW
DECLARE
	date_envoi DATE;
BEGIN
    -- Récupérer la date d'envoi du ticket à gérer
    SELECT date_envoi INTO date_envoi
    FROM Ticket 
    WHERE id_ticket = :NEW.id_ticket;
	
	IF date_envoi > :NEW.Date_récupération THEN
        RAISE_APPLICATION_ERROR(-20004, 'la date est invalide');
	END IF;
END;

-- Procedure : Suppression du groupe si le dernier membre le quitte
CREATE OR REPLACE PROCEDURE SuppressionGroupe (
    p_id_groupe IN Appartient.id_groupe%TYPE,
    p_id_utilisateur IN Appartient.id_utilisateur%TYPE
) AS
    v_nb_membres INTEGER;
BEGIN
    -- Supprimer le membre de la table Appartient
    DELETE FROM Appartient
    WHERE id_groupe = p_id_groupe
    AND id_utilisateur = p_id_utilisateur;
    
    -- Compter le nombre de membres restants dans le groupe
    SELECT COUNT(*)
    INTO v_nb_membres
    FROM Appartient
    WHERE id_groupe = p_id_groupe;

    -- Vérifier si le groupe est maintenant sans membres
    IF v_nb_membres = 0 THEN
        -- Supprimer le groupe de la table Groupe
        DELETE FROM Groupe
        WHERE id_groupe = p_id_groupe;
    END IF;
END;

-- C/ Jeu de données

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
INSERT INTO Groupe VALUES (6, 'Naturalis', 'Groupe de Jardinage');
INSERT INTO Groupe VALUES (7, 'Pfizer Inc.', 'Multinationale pharmaceutique');
INSERT INTO Groupe VALUES (8, 'Toyota Motor Corporation', 'Groupe Automobile');
INSERT INTO Groupe VALUES (9, 'Amazon.com', 'Géant mondial du commerce électronique et des services cloud');
INSERT INTO Groupe VALUES (10, 'Le Super Groupe de Camila', 'Groupe de Camila');

-- Insert Logiciel
INSERT INTO Logiciel VALUES (1, 'NovaWord', 'Créez et formatez vos documents facilement.');
INSERT INTO Logiciel VALUES (2, 'NovaSheet', 'Gérez vos données et effectuez des calculs précis.');
INSERT INTO Logiciel VALUES (3, 'NovaSlide', 'Concevez des présentations dynamiques et percutantes.');
INSERT INTO Logiciel VALUES (4, 'NovaNote', 'Organisez vos idées et listes de tâches en un seul endroit.');
INSERT INTO Logiciel VALUES (5, 'NovaCalendar', 'Planifiez vos événements et suivez votre emploi du temps.');
INSERT INTO Logiciel VALUES (6, 'NovaConnect', 'Collaborez efficacement avec des outils de communication intégrés.');

-- Insert Ticket
INSERT INTO Ticket VALUES (1, 'Rappel manquant', 'Événement du calendrier non notifié.', 'NovaCalendar', 1, '10-jan-2023', 'Traité');
INSERT INTO Ticket VALUES (2, 'Erreur de sauvegarde', 'Impossible de sauvegarder le document.', 'NovaWord', 2, '15-feb-2023', 'Traité');
INSERT INTO Ticket VALUES (3, 'Formule erronée', 'Les résultats des calculs sont incorrects.', 'NovaSheet', 3, '20-mar-2023', 'Traité');
INSERT INTO Ticket VALUES (4, 'Animation défectueuse', 'Les transitions ne fonctionnent pas.', 'NovaSlide', 4, '25-apr-2023', 'Traité');
INSERT INTO Ticket VALUES (5, 'Notes disparues', 'Perte de toutes les notes enregistrées.', 'NovaNote', 5, '30-may-2023', 'Traité');
INSERT INTO Ticket VALUES (6, 'Connexion instable', 'Déconnexions fréquentes de la plateforme.', 'NovaConnect', 6, '05-jun-2023', 'Traité');
INSERT INTO Ticket VALUES (7, 'Police illisible', 'Texte flou.', 'NovaWord', 7, '10-jul-2023', 'Traité');
INSERT INTO Ticket VALUES (8, 'Cellules vides', 'Données disparues dans le tableau.', 'NovaSheet', 8, '15-aug-2023', 'En attente');
INSERT INTO Ticket VALUES (9, 'Graphique déformé', 'Distorsion des éléments graphiques.', 'NovaSlide', 9, '20-sep-2023', 'Traité');
INSERT INTO Ticket VALUES (10, 'Carnet inaccessible', 'Carnet de notes inaccessible.', 'NovaNote', 10, '25-oct-2023', 'Traité');
INSERT INTO Ticket VALUES (11, 'Événement non enregistré', 'Nouvel événement non ajouté au calendrier.', 'NovaCalendar', 11, '30-nov-2023', 'Traité');
INSERT INTO Ticket VALUES (12, 'Audio perturbé', 'Problèmes de son lors des appels.', 'NovaConnect', 12, '05-dec-2023', 'Traité');
INSERT INTO Ticket VALUES (13, 'Mise en page altérée', 'Disposition du document désorganisée.', 'NovaWord', 13, '10-jan-2024', 'Traité');
INSERT INTO Ticket VALUES (14, 'Fonction de tri inopérante', 'Tri des données incorrect dans le tableau.', 'NovaSheet', 14, '15-feb-2024', 'En attente');
INSERT INTO Ticket VALUES (15, 'Diapositive manquante', 'Perte de diapositive lors de la présentation.', 'NovaSlide', 15, '20-mar-2024', 'En attente');
INSERT INTO Ticket VALUES (16, 'Notes non sauvegardées', 'Modifications non enregistrées dans NovaNote.', 'NovaNote', 16, '25-apr-2024', 'Traité');
INSERT INTO Ticket VALUES (17, 'Doublon', 'Evénements dupliqués dans NovaCalendar.', 'NovaCalendar', 17, '30-may-2024', 'En attente');
INSERT INTO Ticket VALUES (18, 'Appel interrompu', 'Interruption inattendue des appels vidéo.', 'NovaConnect', 18, '05-jun-2024', 'Traité');
INSERT INTO Ticket VALUES (19, 'Erreur encodage', 'Caractères spéciaux mal affichés.', 'NovaWord', 19, '10-jul-2024', 'Traité');
INSERT INTO Ticket VALUES (20, 'Formule manquante', 'Absence de certaines fonctions dans NovaSheet.', 'NovaSheet', 20, '15-aug-2024', 'En attente');
INSERT INTO Ticket VALUES (21, 'Animation gelée', 'Gel de la transition sur NovaSlide.', 'NovaSlide', 21, '20-sep-2024', 'En attente');
INSERT INTO Ticket VALUES (22, 'Synchronisation échouée', 'Données non synchronisées sur NovaNote.', 'NovaNote', 22, '25-oct-2024', 'En attente');
INSERT INTO Ticket VALUES (23, 'Date erronée', 'Erreur de date dans NovaCalendar.', 'NovaCalendar', 23, '30-nov-2024', 'En attente');
INSERT INTO Ticket VALUES (24, 'Connexion refusée', 'Accès refusé à NovaConnect.', 'NovaConnect', 24, '05-dec-2024', 'En attente');
INSERT INTO Ticket VALUES (25, 'Tableau corrompu', 'Données illisibles dans NovaSheet.', 'NovaSheet', 25, '10-jan-2025', 'Traité');
INSERT INTO Ticket VALUES (26, 'Slide vierge', 'Contenu disparu de NovaSlide.', 'NovaSlide', 26, '15-feb-2025', 'En attente');
INSERT INTO Ticket VALUES (27, 'Carnet effacé', 'Perte totale des notes dans NovaNote.', 'NovaNote', 27, '20-mar-2025', 'En attente');
INSERT INTO Ticket VALUES (28, 'Rappel erratique', 'Rappels aléatoires dans NovaCalendar.', 'NovaCalendar', 28, '25-apr-2025', 'En attente');
INSERT INTO Ticket VALUES (29, 'Audio décalé', 'Désynchronisation du son sur NovaConnect.', 'NovaConnect', 29, '30-may-2025', 'En attente');
INSERT INTO Ticket VALUES (30, 'Formule obsolète', 'Fonction dépréciée dans NovaSheet.', 'NovaSheet', 30, '05-jun-2025', 'En attente');

-- Insert Licence
INSERT INTO Licence VALUES (1, 30, 10, 'Licence 1');
INSERT INTO Licence VALUES (2, 365, 100, 'Licence 2');
INSERT INTO Licence VALUES (3, 30, 19.90, 'Licence 3');
INSERT INTO Licence VALUES (4, 365, 150, 'Licence 4');
INSERT INTO Licence VALUES (5, 30, 49.90, 'Licence 5');
INSERT INTO Licence VALUES (6, 365, 200, 'Licence 6');

-- Insert AchatUtilisateur
INSERT INTO AchatUtilisateur VALUES (1, 1, '10-feb-2023');
INSERT INTO AchatUtilisateur VALUES (2, 2, '15-feb-2023');
INSERT INTO AchatUtilisateur VALUES (3, 3, '20-mar-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, '10-apr-2023');
INSERT INTO AchatUtilisateur VALUES (3, 3, '20-apr-2023');
INSERT INTO AchatUtilisateur VALUES (4, 4, '25-apr-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, '10-may-2023');
INSERT INTO AchatUtilisateur VALUES (4, 2, '26-may-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, '30-may-2023');
INSERT INTO AchatUtilisateur VALUES (6, 6, '05-jun-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, '10-jun-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, '30-jun-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, '10-jul-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, '30-jul-2023');
INSERT INTO AchatUtilisateur VALUES (1, 1, '10-aug-2023');
INSERT INTO AchatUtilisateur VALUES (5, 5, '30-aug-2023');
INSERT INTO AchatUtilisateur VALUES (1, 2, '10-sep-2023');
INSERT INTO AchatUtilisateur VALUES (8, 2, '10-oct-2023');
INSERT INTO AchatUtilisateur VALUES (9, 4, '25-nov-2023');
INSERT INTO AchatUtilisateur VALUES (10, 5, '30-dec-2023');
INSERT INTO AchatUtilisateur VALUES (11, 6, '05-jan-2024');
INSERT INTO AchatUtilisateur VALUES (10, 5, '01-feb-2024');
INSERT INTO AchatUtilisateur VALUES (12, 6, '05-feb-2024');
INSERT INTO AchatUtilisateur VALUES (2, 2, '15-feb-2024');
INSERT INTO AchatUtilisateur VALUES (10, 5, '02-mar-2024');
INSERT INTO AchatUtilisateur VALUES (13, 1, '10-mar-2024');
INSERT INTO AchatUtilisateur VALUES (13, 1, '10-apr-2024');
INSERT INTO AchatUtilisateur VALUES (14, 2, '15-apr-2024');
INSERT INTO AchatUtilisateur VALUES (4, 4, '25-apr-2024');
INSERT INTO AchatUtilisateur VALUES (15, 3, '20-may-2024');
INSERT INTO AchatUtilisateur VALUES (6, 6, '05-jun-2024');
INSERT INTO AchatUtilisateur VALUES (16, 4, '25-jun-2024');
INSERT INTO AchatUtilisateur VALUES (17, 5, '30-jul-2024');
INSERT INTO AchatUtilisateur VALUES (18, 6, '05-aug-2024');
INSERT INTO AchatUtilisateur VALUES (17, 5, '30-aug-2024');
INSERT INTO AchatUtilisateur VALUES (19, 1, '10-sep-2024');
INSERT INTO AchatUtilisateur VALUES (19, 1, '10-oct-2024');
INSERT INTO AchatUtilisateur VALUES (20, 2, '15-oct-2024');
INSERT INTO AchatUtilisateur VALUES (19, 1, '10-nov-2024');
INSERT INTO AchatUtilisateur VALUES (21, 4, '20-nov-2024');

-- Insert AchatGroupe
INSERT INTO AchatGroupe VALUES (1, 4, '10-jan-2023');
INSERT INTO AchatGroupe VALUES (2, 2, '15-feb-2023');
INSERT INTO AchatGroupe VALUES (3, 6, '20-mar-2023');
INSERT INTO AchatGroupe VALUES (4, 6, '25-apr-2023');
INSERT INTO AchatGroupe VALUES (5, 4, '30-may-2023');
INSERT INTO AchatGroupe VALUES (6, 4, '05-jun-2023');
INSERT INTO AchatGroupe VALUES (7, 4, '10-jul-2023');
INSERT INTO AchatGroupe VALUES (8, 2, '15-aug-2023');
INSERT INTO AchatGroupe VALUES (9, 2, '20-sep-2023');
INSERT INTO AchatGroupe VALUES (10, 6, '25-oct-2023');
INSERT INTO AchatGroupe VALUES (1, 4, '10-jan-2024');
INSERT INTO AchatGroupe VALUES (2, 2, '15-feb-2024');
INSERT INTO AchatGroupe VALUES (3, 6, '20-mar-2024');
INSERT INTO AchatGroupe VALUES (4, 6, '25-apr-2024');
INSERT INTO AchatGroupe VALUES (5, 4, '30-may-2024');
INSERT INTO AchatGroupe VALUES (6, 4, '05-jun-2024');
INSERT INTO AchatGroupe VALUES (7, 4, '10-jul-2024');
INSERT INTO AchatGroupe VALUES (8, 2, '15-aug-2024');
INSERT INTO AchatGroupe VALUES (9, 2, '20-sep-2024');
INSERT INTO AchatGroupe VALUES (10, 6, '25-oct-2024');
INSERT INTO AchatGroupe VALUES (1, 4, '10-jan-2025');
INSERT INTO AchatGroupe VALUES (2, 2, '15-feb-2025');
INSERT INTO AchatGroupe VALUES (3, 6, '20-mar-2025');
INSERT INTO AchatGroupe VALUES (4, 6, '25-apr-2025');
INSERT INTO AchatGroupe VALUES (5, 4, '30-may-2025');
INSERT INTO AchatGroupe VALUES (6, 4, '05-jun-2025');
INSERT INTO AchatGroupe VALUES (7, 4, '10-jul-2025');
INSERT INTO AchatGroupe VALUES (8, 2, '15-aug-2025');
INSERT INTO AchatGroupe VALUES (9, 2, '20-sep-2025');
INSERT INTO AchatGroupe VALUES (10, 6, '25-oct-2025');

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

-- Insert Récupère
INSERT INTO Récupère VALUES (1, 19, '20-jun-2022');
INSERT INTO Récupère VALUES (2, 1, '18-jul-2022');
INSERT INTO Récupère VALUES (2, 18, '10-sep-2022');
INSERT INTO Récupère VALUES (2, 13, '15-nov-2022');
INSERT INTO Récupère VALUES (2, 12, '14-jan-2023');
INSERT INTO Récupère VALUES (1, 11, '19-mar-2023');
INSERT INTO Récupère VALUES (1, 10, '24-apr-2023');
INSERT INTO Récupère VALUES (1, 9, '11-may-2023');
INSERT INTO Récupère VALUES (5, 25, '29-jun-2023');
INSERT INTO Récupère VALUES (5, 7, '10-jul-2023');
INSERT INTO Récupère VALUES (2, 6, '15-aug-2023');
INSERT INTO Récupère VALUES (8, 5, '20-sep-2023');
INSERT INTO Récupère VALUES (9, 4, '25-oct-2023');
INSERT INTO Récupère VALUES (2, 3, '30-nov-2023');
INSERT INTO Récupère VALUES (2, 2, '20-dec-2023');
INSERT INTO Récupère VALUES (8, 16, '25-jan-2024');

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
-- Quels sont tous les tickets ?
select * from Ticket;
-- Quelles sont toutes les licences ?
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
-- Quel utilisateur appartient à quel groupe ?
select * from Appartient;
-- Quels logiciels sont inclus dans quelles licences ?
select * from Inclue;

-- Combien de licences les groupes ont-ils achetés ?
select distinct g.Nom, count(ag.id_groupe) as "Nombre de licences achetées"
from Groupe g, AchatGroupe ag
where g.id_groupe = ag.id_groupe
group by g.Nom;

-- Combien de licences ont acheté les groupes en moyenne ?
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

-- Combien d'employés sont dans la SAAS ?
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
select sum(l.Prix) as "Argent gagné"
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

-- Quels logiciels ont été modifiés le plus suite à des Tickets ?
select l.Nom as "Nom du logiciel", COUNT(*) as "Nombre de modifications"
from Ticket t, Modifie m
join Logiciel l on m.id_logiciel = l.id_logiciel
where t.Logiciel_concerné like l.Nom
group by l.Nom
order by COUNT(*) desc;

-- Quel argent les Utilisateurs ont ils rapporté à la Saas ?
SELECT l.id_licence, (COUNT(au.id_licence) + COUNT(ag.id_licence)) * l.prix AS "Argent Rapporté"
FROM AchatUtilisateur au
JOIN Licence l ON au.id_licence = l.id_licence
JOIN AchatGroupe ag ON ag.id_licence = l.id_licence
GROUP BY l.id_licence, l.prix
ORDER BY (COUNT(au.id_licence) + COUNT(ag.id_licence)) * l.prix DESC;

-- Quel argent les groupes ont rapporté à la Saas ?
SELECT l.id_licence, COUNT(ag.id_licence) * l.prix AS "Argent Rapporté"
FROM AchatGroupe ag
JOIN Licence l ON ag.id_licence = l.id_licence
GROUP BY l.id_licence, l.prix
ORDER BY COUNT(ag.id_licence) * l.prix DESC;

-- E/ Vues

-- Vue 1 : Affiche les détails des licences achetées par les utilisateurs.
CREATE OR REPLACE VIEW UtilisateurAchatLicence AS
SELECT U.id_utilisateur, U.Nom, U.Prenom, A.Date_achat, L.*
FROM Utilisateur U
JOIN AchatUtilisateur A ON U.id_utilisateur = A.id_utilisateur
JOIN Licence L ON A.id_licence = L.id_licence;
SELECT * FROM UtilisateurAchatLicence;

-- Vue 2 : Affiche les détails des licences achetées par les groupes.
CREATE OR REPLACE VIEW GroupeAchatLicence AS
SELECT G.id_groupe, G.Nom, A.Date_achat, L.*
FROM Groupe G
JOIN AchatGroupe A ON G.id_groupe = A.id_groupe
JOIN Licence L ON A.id_licence = L.id_licence;
SELECT * FROM GroupeAchatLicence;

-- Vue 3 : Affiche les détails des modifications de logiciels effectuées par les employés.
CREATE OR REPLACE VIEW EmployeModifieLogiciel AS
SELECT E.id_employé, E.Nom AS "Nom Employe", E.Prenom, M.Date_modification, M.Version, L.*
FROM Employé E
JOIN Modifie M ON E.id_employé = M.id_employé
JOIN Logiciel L ON M.id_logiciel = L.id_logiciel;
SELECT * FROM EmployeModifieLogiciel;

-- Vue 4 : Affiche les détails de la gestion des licences par les employés.
CREATE OR REPLACE VIEW EmployeGereLicence AS
SELECT E.id_employé, E.Nom as "Nom Employe", E.Prenom, G.Date_modification, L.*
FROM Employé E
JOIN Gère G ON E.id_employé = G.id_employé
JOIN Licence L ON G.id_licence = L.id_licence;
SELECT * FROM EmployeGereLicence;

-- Vue 5 : NombreUtilisateursParGroupe récupère le nombre d'utilisateurs par groupe.
CREATE OR REPLACE VIEW NombreUtilisateursParGroupe AS
SELECT G.id_groupe, G.Nom, COUNT(A.id_utilisateur) AS Nombre_Utilisateurs
FROM Groupe G LEFT JOIN Appartient A ON G.id_groupe = A.id_groupe
GROUP BY G.id_groupe, G.Nom;
SELECT * FROM NombreUtilisateursParGroupe;

-- Vue 6 : StatistiquesUtilisateur récupère les utilisateurs ainsi que le nombre d'achat de licences et les dépenses moyennes de chaque utilisateur.
CREATE OR REPLACE VIEW StatistiquesUtilisateur AS
SELECT U.id_utilisateur, U.Nom, U.Prenom, COUNT(A.id_licence) AS Nombre_Achats, AVG(L.Prix) AS Prix_Moyen
FROM Utilisateur U LEFT JOIN AchatUtilisateur A ON U.id_utilisateur = A.id_utilisateur LEFT JOIN Licence L ON A.id_licence = L.id_licence
GROUP BY U.id_utilisateur, U.Nom, U.Prenom;
SELECT * FROM StatistiquesUtilisateur;

-- Vue 7 : StatistiquesGroupe récupère les groupes ainsi que le nombre d'achat de licences et la dépense totale du groupe.
CREATE OR REPLACE VIEW StatistiquesGroupe AS
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

-- Vue 9 : MembresGroupe récupère les membres du groupe de l'utilisateur.
CREATE OR REPLACE VIEW MembresGroupe as
SELECT U.id_utilisateur, U.Nom, U.Prenom, U.Email
FROM Utilisateur U, Appartient A, Groupe G
WHERE U.id_utilisateur = A.id_utilisateur AND A.id_groupe = G.id_groupe;
SELECT * FROM MembresGroupe;

CREATE ROLE Utilisateur;
CREATE ROLE Employé;
CREATE ROLE Groupe;

GRANT SELECT ON UtilisateurAchatLicence TO Employé WHERE Poste = 'Commercial';
GRANT SELECT ON GroupeAchatLicence TO Employé WHERE Poste = 'Commercial';
GRANT SELECT ON EmployeModifieLogiciel TO Employé WHERE Poste = 'Développeur';
GRANT SELECT ON EmployeGereLicence TO Employé WHERE Poste = 'Commercial';
GRANT SELECT ON NombreUtilisateursParGroupe TO Employé WHERE Poste = 'Commercial';
GRANT SELECT ON NombreUtilisateursParGroupe TO Utilisateur WHERE id_utilisateur Appartient.id_utilisateur AND Appartient.id_groupe = Groupe.id_groupe
GRANT SELECT ON StatistiquesUtilisateur TO Employé WHERE Poste = 'Commercial';
GRANT SELECT ON StatistiquesGroupe TO Employé WHERE Poste = 'Commercial';
GRANT SELECT ON SalaireMoyenParPoste TO Employé WHERE Poste = 'Chef';
GRANT SELECT ON MembresGroupe TO Utilisateur WHERE id_utilisateur Appartient.id_utilisateur AND Appartient.id_groupe = Groupe.id_groupe;

-- Autres Permissions

-- L'Employé qui a le poste Chef peut tout faire.
GRANT ALL ON Utilisateur TO Employé WHERE Poste = 'Chef';
GRANT ALL ON Groupe TO Employé WHERE Poste = 'Chef';
GRANT ALL ON Logiciel TO Employé WHERE Poste = 'Chef';
GRANT ALL ON Ticket TO Employé WHERE Poste = 'Chef';
GRANT ALL ON Licence TO Employé WHERE Poste = 'Chef';

-- L'Employé qui a le poste Développeur peut modifier un logiciel.
GRANT UPDATE ON Logiciel TO Employé WHERE Poste = 'Développeur';

-- L'Employé qui a le poste Commercial peut gérer une licence.
GRANT UPDATE ON Licence TO Employé WHERE Poste = 'Commercial';

-- L'Employé qui a le poste Support peut modifier un ticket.
GRANT UPDATE ON Ticket TO Employé WHERE Poste = 'Support';

-- L'Utilisateur peut créer un groupe et un ticket.
GRANT INSERT ON Groupe TO Utilisateur;
GRANT INSERT ON Ticket TO Utilisateur;

-- L'Utilisateur peut acheter une licence.
GRANT INSERT ON AchatUtilisateur TO Utilisateur;

-- L'Utilisateur peut rejoindre un groupe.
GRANT INSERT ON Appartient TO Utilisateur;

-- Le Groupe peut acheter une licence.
GRANT INSERT ON AchatGroupe TO Groupe;

-- Le Groupe peut ajouter un utilisateur.
GRANT INSERT ON Appartient TO Groupe;

-- Les membres d'un groupe peuvent voir modifier le nom et la description du groupe.
GRANT SELECT, UPDATE ON Groupe TO Appartient;

-- Les membres d'un groupe peuvent voir les utilisateurs du groupe.
GRANT SELECT ON Appartient TO Utilisateur WHERE id_utilisateur = Appartient.id_utilisateur AND Appartient.id_groupe = Groupe.id_groupe;

-- F/ Méta-données

-- Liste des contraintes d'intégrité dans le fichier liste_ora_constraints
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE, SEARCH_CONDITION
FROM USER_CONSTRAINTS
WHERE OWNER = USER
ORDER BY TABLE_NAME, CONSTRAINT_TYPE;

-- Liste des triggers dans le fichier liste_ora_triggers
SELECT TABLE_NAME, TRIGGER_NAME, TRIGGER_TYPE, TRIGGERING_EVENT, TRIGGER_BODY
FROM USER_TRIGGERS
WHERE OWNER = USER
ORDER BY TABLE_NAME;

-- Liste des tables dans le fichier liste_ora_tables
SELECT TABLE_NAME
FROM USER_TABLES
WHERE OWNER = USER;

-- Liste des vues dans le fichier liste_ora_vues
SELECT VIEW_NAME
FROM USER_VIEWS
WHERE OWNER = USER;

-- Liste des procédures dans le fichier liste_ora_procedures
SELECT OBJECT_NAME
FROM USER_OBJECTS
WHERE OBJECT_TYPE = 'PROCEDURE' AND OWNER = USER;
